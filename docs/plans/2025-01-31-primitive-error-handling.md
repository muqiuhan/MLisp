# Primitive Error Handling Improvement Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve error messages in OCaml primitive function bindings to distinguish between type errors, argument count errors, and value errors, providing clearer feedback to users.

**Architecture:** Add new error variants to `runtime_error` type, create helper functions for parameter validation in `primitives`, and update existing primitive functions to use the improved error handling.

**Tech Stack:** OCaml 5.0+, Dune 3.3+, Core library

---

## Overview

Current OCaml primitive function bindings use `Parse_error_exn` with generic `Type_error` messages that don't distinguish between:
- Wrong number of arguments
- Wrong type of arguments
- Invalid values (e.g., out of bounds)

This plan introduces:
1. New error variants: `Argument_count_error`, `Argument_type_error`, `Value_error`
2. Helper functions for common validation patterns
3. Updated error messages with specific, actionable feedback

---

## Task 1: Extend Error Types

**Files:**
- Modify: `lib/error/errors.ml:20-28`

**Step 1: Add new runtime_error variants**

Find the `runtime_error` type definition (around line 20) and add new variants:

```ocaml
type runtime_error =
  | Not_found of string
  | Unspecified_value of string
  | Missing_argument of string list
  | Non_definition_in_stdlib of string
  | Not_a_module of string
  | Export_not_found of string * string
  | Module_load_error of string * string
  | Argument_count_error of string * int * int  (* function_name, expected, got *)
  | Argument_type_error of string * string * string  (* function_name, param_name, expected_type *)
  | Value_error of string * string  (* function_name, description *)
```

**Step 2: Build and verify**

Run: `dune build`
Expected: SUCCESS - type compiles correctly

**Step 3: Commit**

```bash
git add lib/error/errors.ml
git commit -m "feat(error): add Argument_count_error, Argument_type_error, Value_error variants"
```

---

## Task 2: Add Error Code for New Error Types

**Files:**
- Modify: `lib/error/codes.ml`

**Step 1: Read the file to understand the pattern**

Run: `cat lib/error/codes.ml`

**Step 2: Add error codes for new error types**

Based on the existing pattern, add codes for the new error types. They should use code "E003" or similar.

**Step 3: Build and verify**

Run: `dune build`
Expected: SUCCESS

**Step 4: Commit**

```bash
git add lib/error/codes.ml
git commit -m "feat(error): add error codes for argument and value errors"
```

---

## Task 3: Create Validation Helper Module

**Files:**
- Create: `lib/primitives/validate.ml`

**Step 1: Write the validation helper module**

Create a new module with reusable validation functions:

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core

(** Validation helpers for primitive functions.

    This module provides reusable functions for validating arguments
    to primitive functions, with consistent and helpful error messages. *)

(** Check argument count and raise if incorrect.

    @param func_name Name of the function (for error messages)
    @param args List of arguments received
    @param expected Expected number of arguments
    @raise Runtime_error_exn if count doesn't match
*)
let check_arg_count func_name args expected =
  let got = List.length args in
  if got <> expected then
    raise
      (Errors.Runtime_error_exn
         (Errors.Argument_count_error (func_name, expected, got)))

(** Check minimum argument count and raise if too few.

    @param func_name Name of the function
    @param args List of arguments received
    @param min_required Minimum number of arguments required
    @raise Runtime_error_exn if too few arguments
*)
let check_min_args func_name args min_required =
  let got = List.length args in
  if got < min_required then
    raise
      (Errors.Runtime_error_exn
         (Errors.Argument_count_error (func_name, min_required, got)))

(** Validate that an argument is a String.

    @param func_name Name of the function
    @param param_name Name of the parameter (for error messages)
    @param value The argument value to check
    @return The string value if valid
    @raise Runtime_error_exn if not a String
*)
let require_string func_name param_name = function
  | Object.String s -> s
  | other ->
      let expected_type = "string" in
      raise
        (Errors.Runtime_error_exn
           (Errors.Argument_type_error (func_name, param_name, expected_type)))

(** Validate that an argument is a Fixnum.

    @param func_name Name of the function
    @param param_name Name of the parameter
    @param value The argument value to check
    @return The integer value if valid
    @raise Runtime_error_exn if not a Fixnum
*)
let require_int func_name param_name = function
  | Object.Fixnum n -> Int.to_int_exn n
  | other ->
      raise
        (Errors.Runtime_error_exn
           (Errors.Argument_type_error (func_name, param_name, "integer")))

(** Validate that an argument is a Number (Fixnum or Float).

    @param func_name Name of the function
    @param param_name Name of the parameter
    @param value The argument value to check
    @return The value as float if valid
    @raise Runtime_error_exn if not a number
*)
let require_number func_name param_name = function
  | Object.Fixnum n ->
      Float.of_int (Int.to_int_exn n)
  | Object.Float f ->
      f
  | other ->
      raise
        (Errors.Runtime_error_exn
           (Errors.Argument_type_error (func_name, param_name, "number")))

(** Validate that an argument is a proper list (Nil or Pair).

    @param func_name Name of the function
    @param param_name Name of the parameter
    @param value The argument value to check
    @return The list as OCaml list if valid
    @raise Runtime_error_exn if not a proper list
*)
let require_list func_name param_name = function
  | Object.Nil ->
      []
  | Object.Pair _ as pair ->
      Object.pair_to_list pair
  | other ->
      raise
        (Errors.Runtime_error_exn
           (Errors.Argument_type_error (func_name, param_name, "list")))

(** Check that an integer is within a range.

    @param func_name Name of the function
    @param param_name Name of the parameter
    @param value The integer value to check
    @param min_value Minimum allowed value (inclusive)
    @param max_value Maximum allowed value (inclusive), or None for no max
    @return The value if valid
    @raise Runtime_error_exn if out of range
*)
let check_int_range func_name param_name value ?(min_value=None) ?(max_value=None) () =
  let check_min = min_value |> Option.value_map ~default:(fun () -> true) ~f:(fun min -> value >= min) in
  let check_max = max_value |> Option.value_map ~default:(fun () -> true) ~f:(fun max -> value <= max) in
  if not (check_min && check_max) then
    let description =
      match min_value, max_value with
      | Some min, Some max ->
          [%string "must be between %{Int.to_string min} and %{Int.to_string max}"]
      | Some min, None ->
          [%string "must be at least %{Int.to_string min}"]
      | None, Some max ->
          [%string "must be at most %{Int.to_string max}"]
      | None, None ->
          "out of range"
    in
    raise
      (Errors.Runtime_error_exn
         (Errors.Value_error (func_name, [%string "%{param_name} %{description}"])))
  else
    value
```

**Step 2: Update dune file**

Add `validate` to the library sources in `lib/primitives/dune`:

```lisp
(library
 (name mlisp_primitives)
 (libraries mlisp_object mlisp_error core)
 (modules num string std ocaml validate))
```

**Step 3: Build and verify**

Run: `dune build`
Expected: SUCCESS

**Step 4: Commit**

```bash
git add lib/primitives/validate.ml lib/primitives/dune
git commit -m "feat(primitives): add validation helper module"
```

---

## Task 4: Update String Module Bindings

**Files:**
- Modify: `lib/primitives/ocaml.ml:29-128`

**Step 1: Rewrite string_length using helpers**

Replace the existing `string_length` function (lines 29-36):

```ocaml
let string_length = function
  | [ arg ] ->
      let s = Validate.check_arg_count "String.length" [arg] 1
              |> fun () -> Validate.require_string "String.length" "string" arg
      in
      Object.Fixnum (String.length s)
  | args ->
      let got = List.length args in
      raise
        (Errors.Runtime_error_exn
           (Errors.Argument_count_error ("String.length", 1, got)))
```

**Step 2: Rewrite string_concat**

Replace `string_concat` (lines 38-45):

```ocaml
let string_concat = function
  | [ arg1; arg2 ] ->
      let s1 = Validate.require_string "String.concat" "first" arg1 in
      let s2 = Validate.require_string "String.concat" "second" arg2 in
      Object.String (s1 ^ s2)
  | args ->
      let got = List.length args in
      raise
        (Errors.Runtime_error_exn
           (Errors.Argument_count_error ("String.concat", 2, got)))
```

**Step 3: Rewrite string_sub with better error handling**

Replace `string_sub` (lines 83-95):

```ocaml
let string_sub = function
  | [ arg1; arg2; arg3 ] ->
      let s = Validate.require_string "String.sub" "string" arg1 in
      let pos = Validate.require_int "String.sub" "pos" arg2 in
      let len = Validate.require_int "String.sub" "len" arg3 in
      (* Validate bounds *)
      let s_len = String.length s in
      if pos < 0 || len < 0 then
        raise
          (Errors.Runtime_error_exn
             (Errors.Value_error ("String.sub", "position and length must be non-negative")))
      else if pos + len > s_len then
        raise
          (Errors.Runtime_error_exn
             (Errors.Value_error ("String.sub", [%string "substring out of bounds (string length: %{Int.to_string s_len}, requested: %{Int.to_string pos} + %{Int.to_string len})"])))
      else
        Object.String (String.sub s ~pos ~len)
  | args ->
      let got = List.length args in
      raise
        (Errors.Runtime_error_exn
           (Errors.Argument_count_error ("String.sub", 3, got)))
```

**Step 4: Update other string functions**

Update `string_upper`, `string_lower`, `string_split`, `string_contains`, `string_trim` following the same pattern.

**Step 5: Build and test**

Run: `dune build && dune exec mlisp -- test/50_ocaml_string.mlisp`
Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/primitives/ocaml.ml
git commit -m "feat(primitives): improve String module error messages"
```

---

## Task 5: Update List Module Bindings

**Files:**
- Modify: `lib/primitives/ocaml.ml:141-298`

**Step 1: Rewrite list_length**

```ocaml
let list_length = function
  | [ arg ] ->
      (Validate.require_list "List.length" "list" arg
       |> fun lst -> Object.Fixnum (List.length lst))
  | args ->
      let got = List.length args in
      raise
        (Errors.Runtime_error_exn
           (Errors.Argument_count_error ("List.length", 1, got)))
```

**Step 2: Rewrite list_nth with better bounds checking**

```ocaml
let list_nth = function
  | [ arg1; arg2 ] ->
      let lst = Validate.require_list "List.nth" "list" arg1 in
      let idx = Validate.require_int "List.nth" "index" arg2 in
      if idx < 0 then
        raise
          (Errors.Runtime_error_exn
             (Errors.Value_error ("List.nth", "index must be non-negative")))
      else if idx >= List.length lst then
        raise
          (Errors.Runtime_error_exn
             (Errors.Value_error ("List.nth", [%string "index out of bounds (list length: %{Int.to_string (List.length lst)}, index: %{Int.to_string idx})"])))
      else
        List.nth_exn lst idx
  | args ->
      let got = List.length args in
      raise
        (Errors.Runtime_error_exn
           (Errors.Argument_count_error ("List.nth", 2, got)))
```

**Step 3: Update other list functions**

Update `list_append`, `list_rev`, `list_mem`, `list_flatten`, `list_concat`, `list_sort` following the same pattern.

**Step 4: Build and test**

Run: `dune build && dune exec mlisp -- test/51_ocaml_list.mlisp`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/primitives/ocaml.ml
git commit -m "feat(primitives): improve List module error messages"
```

---

## Task 6: Update Error Reporting for New Error Types

**Files:**
- Modify: `lib/error/codes.ml`
- Modify: `lib/error/error.ml` (if needed)

**Step 1: Add error code mappings for new error types**

In `codes.ml`, add mappings for:
- `Argument_count_error` -> "E003" (or next available code)
- `Argument_type_error` -> "E004"
- `Value_error` -> "E005"

**Step 2: Update error message formatting**

The error messages should display as:
```
[error E003]: Argument count error: String.length expects 1 argument, got 0

Example: (String.length "hello") works, but (String.length) does not
```

**Step 3: Build and verify**

Run: `dune build`
Expected: SUCCESS

**Step 4: Commit**

```bash
git add lib/error/codes.ml lib/error/error.ml
git commit -m "feat(error): add error code mappings for new error types"
```

---

## Task 7: Write Comprehensive Error Tests

**Files:**
- Create: `test/55_error_messages.mlisp`

**Step 1: Write error message tests**

```lisp
;; Test error messages for primitive functions

;; Test 1: Argument count error - too few
(print "Test 1: String.length with no args")
(ocall String length)  ;; Should say: expects 1 argument, got 0

;; Test 2: Argument count error - too many
(print "Test 2: String.length with too many args")
(ocall String length "hello" "world")  ;; Should say: expects 1 argument, got 2

;; Test 3: Argument type error
(print "Test 3: String.length with number")
(ocall String length 123)  ;; Should say: expected string, got number

;; Test 4: Value error - negative index
(print "Test 4: String.sub with negative index")
(ocall String.sub "hello" -1 3)  ;; Should say: position and length must be non-negative

;; Test 5: Value error - out of bounds
(print "Test 5: String.sub out of bounds")
(ocall String.sub "hello" 10 3)  ;; Should say: substring out of bounds with details

;; Test 6: List.nth out of bounds
(print "Test 6: List.nth out of bounds")
(ocall List.nth (quote (1 2 3)) 5)  ;; Should say: index out of bounds with details

;; Test 7: List.nth with non-list
(print "Test 7: List.nth with non-list")
(ocall List.nth 123 0)  ;; Should say: expected list, got number

;; Test 8: List.append with wrong types
(print "Test 8: List.append with non-list")
(ocall List.append 123 (quote (1 2)))  ;; Should say: expected list, got number

(print "All error message tests complete")
```

**Step 2: Run tests to verify error messages**

Run: `dune exec mlisp -- test/55_error_messages.mlisp 2>&1 | grep -A2 "Test\|error"`

Expected: Clear, specific error messages for each case

**Step 3: Commit**

```bash
git add test/55_error_messages.mlisp
git commit -m "test: add error message quality tests"
```

---

## Task 8: Update Documentation

**Files:**
- Modify: `README.md`

**Step 1: Add section on error messages**

Add a new section after "Language Overview" explaining:
- Types of errors (Argument count, Type, Value)
- How error messages are structured
- Examples of common errors and their messages

**Step 2: Update standard library documentation**

Add error behavior notes to function documentation:
- Which functions validate argument counts
- Which functions have value constraints (e.g., non-negative indices)
- What error messages look like

**Step 3: Run tests**

Run: `./run_tests.sh`
Expected: All tests pass

**Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document error message improvements"
```

---

## Task 9: Run Full Test Suite

**Files:**
- Test: All test files

**Step 1: Run full test suite**

Run: `./run_tests.sh -v`
Expected: All existing tests still pass

**Step 2: Verify error message quality**

Run: `dune exec mlisp -- test/55_error_messages.mlisp`
Expected: Clear, actionable error messages

**Step 3: Check for regressions**

Ensure no existing functionality broke.

**Step 4: Final commit if needed**

```bash
git commit --allow-empty -m "feat: primitive error handling improvement complete"
```

---

## Summary of Changes

1. **lib/error/errors.ml**: Added `Argument_count_error`, `Argument_type_error`, `Value_error` variants
2. **lib/error/codes.ml**: Added error code mappings for new error types
3. **lib/primitives/validate.ml**: Created reusable validation helper module
4. **lib/primitives/ocaml.ml**: Updated String and List module bindings with improved error handling
5. **test/55_error_messages.mlisp**: Added comprehensive error message tests
6. **README.md**: Updated documentation

## Implementation Notes

- **Backward Compatibility**: All changes preserve existing behavior for valid inputs
- **Error Messages**: New messages are more specific about what went wrong
- **Helper Functions**: `Validate` module reduces code duplication across primitives
- **Testing**: Tests verify both error conditions and message quality
