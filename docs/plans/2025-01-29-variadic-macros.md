# Variadic Macros Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add support for variadic (rest parameter) macros to MLisp, enabling macros to accept variable numbers of arguments using a `&rest` syntax.

**Architecture:** Extend the AST parser to recognize `&rest` parameters in macro definitions, modify macro expansion to pack extra arguments into a list, and update parameter binding logic to handle both fixed and rest parameters.

**Tech Stack:** OCaml 5.0+, Dune build system, Core library

---

## Overview

This plan implements variadic macros similar to Common Lisp's `&rest` or Scheme's dotted parameter syntax. The syntax will be:

```lisp
(defmacro my-macro (required1 required2 &rest rest-params)
  `(body ,required1 ,required2 ,@rest-params))
```

**Key changes:**
1. Extend `lobject` type to represent rest parameters
2. Update AST parser to detect and parse `&rest` syntax
3. Modify macro expansion to pack extra arguments into lists
4. Update `assert_unique_args` to handle rest parameters

---

## Task 1: Add Rest Parameter Type to `lobject`

**Files:**
- Modify: `lib/object/object.ml:17-37`

**Step 1: Add RestParam variant to lobject type**

Find the `lobject` type definition (around line 17) and add a `RestParam` variant:

```ocaml
type lobject =
  | Fixnum of int
  | Float of float
  | Boolean of bool
  | Symbol of string
  | String of string
  | Nil
  | Pair of lobject * lobject
  | Record of name * (name * lobject) list
  | Primitive of string * (lobject list -> lobject)
  | Quote of value
  | Quasiquote of value
  | Unquote of value
  | UnquoteSplicing of value
  | RestParam of string  (** NEW: Rest parameter marker (e.g., &rest) *)
  | Closure of name * name list * expr * closure_data
  | Macro of name * name list * expr * lobject env
  | Module of { name : string; env : lobject env; exports : string list }
```

**Step 2: Update object_type function**

Find `object_type` function (around line 118) and add case for `RestParam`:

```ocaml
let object_type = function
  | Fixnum _ -> "int"
  | Float _ -> "float"
  | Boolean _ -> "boolean"
  | String _ -> "string"
  | Symbol _ -> "symbol"
  | Nil -> "nil"
  | Pair _ -> "pair"
  | Primitive _ -> "primitive"
  | Quote _ -> "quote"
  | Quasiquote _ -> "quasiquote"
  | Unquote _ -> "unquote"
  | UnquoteSplicing _ -> "unquote-splicing"
  | RestParam _ -> "rest-param"  (* NEW *)
  | Closure _ -> "closure"
  | Macro _ -> "macro"
  | Record _ -> "record"
  | Module _ -> "module"
```

**Step 3: Update string_object function**

Find `string_object` function (around line 234) and add case for `RestParam`:

```ocaml
let rec string_object e =
  (* ... existing cases ... *)
  | Macro (name, name_list, _, _) ->
      [%string {|#<macro:%{name}:(%{String.concat ~sep:" " name_list})>|}]
  | RestParam name ->  (* NEW *)
      "&rest " ^ name
  (* ... rest of function ... *)
```

**Step 4: Build and verify**

Run: `dune build`
Expected: SUCCESS - type compiles correctly

**Step 5: Commit**

```bash
git add lib/object/object.ml
git commit -m "feat(object): add RestParam variant to lobject type for variadic macros"
```

---

## Task 2: Recognize &rest in Lexer

**Files:**
- Modify: `lib/lexer/lexer.ml:127-148`

**Step 1: Add &rest as a recognized symbol start character**

Find `is_symbol_start_char` function (around line 127). The `&` character is already included, so no change needed. Verify line 143 contains:

```ocaml
  | '&' ->
    true
```

**Note:** The `&rest` syntax will be parsed as a regular Symbol by the lexer. We'll handle it in the AST parser.

**Step 2: No commit needed**

This is a verification step - `&` is already a valid symbol character.

---

## Task 3: Update AST Parser to Parse &rest Parameters

**Files:**
- Modify: `lib/ast/ast.ml:21-36`

**Step 1: Modify assert_unique_args to handle &rest**

Replace the existing `assert_unique_args` function (lines 21-36) with a new version that returns parameter info including rest parameters:

```ocaml
type param_spec =
  | Fixed of string
  | Rest of string

let rec parse_params : Object.lobject -> param_spec list =
  fun args ->
  match Object.pair_to_list args with
  | [] -> []
  | [Object.Symbol "&rest"; Object.Symbol rest_name] ->
      [Rest rest_name]
  | [Object.Symbol "&rest"; _] ->
      raise (Errors.Parse_error_exn (Errors.Type_error "&rest must be followed by a symbol"))
  | Object.Symbol "&rest" :: _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "&rest must be the last parameter"))
  | Object.Symbol name :: rest when name = "&rest" ->
      raise (Errors.Parse_error_exn (Errors.Type_error "&rest must be followed by a symbol"))
  | Object.Symbol name :: rest ->
      Fixed name :: parse_params (Object.list_to_pair rest)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(declare-expr symbol-name (formals) body)"))

let assert_unique_args : Object.lobject -> param_spec list =
  fun args ->
  let params = parse_params args in
  (* Check that fixed params are unique *)
  let fixed_names = params |> List.filter_map ~f:(function
    | Fixed name -> Some name
    | Rest _ -> None) in
  let () = assert_unique fixed_names in
  (* Check rest name doesn't conflict with fixed names *)
  let rest_name = params |> List.find_map ~f:(function
    | Rest name -> Some name
    | Fixed _ -> None) in
  match rest_name with
  | None -> ()
  | Some rname ->
      if List.mem fixed_names rname ~equal:String.equal then
        raise (Errors.Parse_error_exn (Unique_error rname));
  params
```

**Step 2: Build and verify**

Run: `dune build`
Expected: FAILURE - The type signature of `assert_unique_args` changed, so callers need updating

**Step 3: Note the error**

The error shows which files need updating. This is expected - we'll fix callers in the next tasks.

---

## Task 4: Update Lambda Expression Parsing

**Files:**
- Modify: `lib/ast/ast.ml:170-199`

**Step 1: Update lambda_expr to use param_spec**

Find the `lambda_expr` function (around line 170) and update it to handle param_spec:

```ocaml
and lambda_expr args body =
  let body_expr =
    if Object.is_list body then (
      let body_list = Object.pair_to_list body in
        match body_list with
        | [] ->
          Object.Literal Object.Nil
        | [ single_expr ] ->
          build_ast single_expr
        | _ :: _ ->
          let rec build_sequence = function
            | [] ->
              Object.Literal Object.Nil
            | [ last ] ->
              build_ast last
            | first' :: rest' ->
              let first_expr = build_ast first' in
              let rest_expr' = build_sequence rest' in
                Object.Let (Object.LET, [ "_", first_expr ], rest_expr')
          in
            build_sequence body_list
    ) else
      build_ast body
  in
    (* Convert param_spec to name list - lambdas don't support &rest yet *)
    let param_specs = assert_unique_args args in
    let is_variadic = List.exists param_specs ~f:(function Rest _ -> true | Fixed _ -> false) in
    if is_variadic then
      raise (Errors.Parse_error_exn (Errors.Type_error "Lambda does not support &rest parameters yet"))
    else
      let names = param_specs |> List.map ~f:(function Fixed n -> n | Rest _ -> assert false) in
      Lambda ("lambda", names, body_expr)
```

**Step 2: Build and verify**

Run: `dune build`
Expected: FAILURE - More callers need updating

---

## Task 5: Update Defun Expression Parsing

**Files:**
- Modify: `lib/ast/ast.ml:201-204`

**Step 1: Update defun_expr to use param_spec**

Find the `defun_expr` function (around line 201) and update it:

```ocaml
and defun_expr fn_name args body =
  let param_specs = assert_unique_args args in
  let is_variadic = List.exists param_specs ~f:(function Rest _ -> true | Fixed _ -> false) in
  if is_variadic then
    raise (Errors.Parse_error_exn (Errors.Type_error "defun does not support &rest parameters yet"))
  else
    let names = param_specs |> List.map ~f:(function Fixed n -> n | Rest _ -> assert false) in
    let lam = Object.Lambda (fn_name, names, build_ast body) in
      Object.Defexpr
        (Object.Setq (fn_name, Let (Object.LETREC, [ fn_name, lam ], Object.Var fn_name)))
```

**Step 2: Build and verify**

Run: `dune build`
Expected: FAILURE - Macro definition needs updating

---

## Task 6: Update Macro Definition Parsing - The Core Change

**Files:**
- Modify: `lib/ast/ast.ml:206-209`

**Step 1: Update macro_def_expr to support &rest**

Find the `macro_def_expr` function (around line 206) and update it:

```ocaml
and macro_def_expr macro_name args body =
  let param_specs = assert_unique_args args in
  Object.Defexpr (Object.Defmacro (macro_name, param_specs, build_ast body))
```

**Step 2: Update the Defmacro type in object.ml**

The `Defmacro` constructor needs to store `param_spec list` instead of `name list`.

**First, update the type definition in `lib/object/object.ml`:**

Find the `def` type (around line 83) and update it:

```ocaml
and def =
  | Setq of name * expr
  | Defun of name * name list * expr
  | Defmacro of name * param_spec list * expr  (** Changed: name list -> param_spec list *)
  | Expr of expr

and param_spec =
  | Fixed of string
  | Rest of string
```

**Step 3: Update string_expr in ast.ml for Defmacro**

Find `string_expr` function and update the `Defmacro` case (around line 318):

```ocaml
  | Object.Defexpr (Object.Defmacro (n, ns, e)) ->
      let params_str =
        let param_to_string = function
          | Fixed name -> name
          | Rest name -> "&rest " ^ name
        in
        String.concat ~sep:" " (List.map ns ~f:param_to_string)
      in
        [%string "(defmacro %{n} (%{params_str}) %{string_expr e})"]
```

**Step 4: Update expr_to_sexpr in macro.ml**

Find `expr_to_sexpr` function in `lib/macro/macro.ml` and update the `Defmacro` case (around line 150):

```ocaml
    (** Macro definition: (defmacro name (params...) body) *)
    | Object.Defmacro (name, params, body) ->
      let params_sexpr =
        let param_to_sexpr = function
          | Mlisp_object.Fixed name -> Object.Symbol name
          | Mlisp_object.Rest name ->
              Object.list_to_pair [Object.Symbol "&rest"; Object.Symbol name]
        in
        Object.list_to_pair (List.map params ~f:param_to_sexpr)
      in
        Object.list_to_pair
          [ Object.Symbol "defmacro"
          ; Object.Symbol name
          ; params_sexpr
          ; expr_to_sexpr body
          ]
```

**Step 5: Update MacroDef case too**

Find the `MacroDef` case in `expr_to_sexpr` (around line 198) and update it similarly:

```ocaml
  (** Macro definition (alternate form): (defmacro name (params...) body) *)
  | Object.MacroDef (name, params, body) ->
      let params_sexpr =
        let param_to_sexpr = function
          | Mlisp_object.Fixed name -> Object.Symbol name
          | Mlisp_object.Rest name ->
              Object.list_to_pair [Object.Symbol "&rest"; Object.Symbol name]
        in
        Object.list_to_pair (List.map params ~f:param_to_sexpr)
      in
        Object.list_to_pair
          [ Object.Symbol "defmacro"; Object.Symbol name; params_sexpr; expr_to_sexpr body ]
```

**Step 6: Build and verify**

Run: `dune build`
Expected: FAILURE - Macro expansion logic needs updating

---

## Task 7: Update Macro Expansion to Pack Rest Arguments

**Files:**
- Modify: `lib/macro/macro.ml:231-283` and `lib/macro/macro.ml:403-482`

**Step 1: Add helper function to bind variadic parameters**

Add this helper function before `expand_macro_call` (around line 210):

```ocaml
(** Bind macro parameters to arguments, handling &rest parameters.

    @param param_specs List of parameter specifications (Fixed or Rest)
    @param arg_sexprs List of argument S-expressions
    @param expansion_env Environment to bind parameters in
    @raise Errors.Runtime_error_exn on argument count mismatch
*)
let bind_macro_params param_specs arg_sexprs expansion_env =
  (* Count fixed parameters *)
  let fixed_count =
    List.fold param_specs ~init:0 ~f:(fun acc -> function
      | Fixed _ -> acc + 1
      | Rest _ -> acc)
  in

  (* Check if variadic *)
  let has_rest =
    List.exists param_specs ~f:(function Rest _ -> true | Fixed _ -> false)
  in

  (* Validate argument count *)
  let arg_count = List.length arg_sexprs in
  if has_rest then
    if arg_count < fixed_count then
      let expected = fixed_count in
      raise
        (Errors.Runtime_error_exn
           (Errors.Not_found
              [%string "Macro expects at least %{Int.to_string expected} arguments, got %{Int.to_string arg_count}"]))
  else
    if arg_count <> fixed_count then
      raise
        (Errors.Runtime_error_exn
           (Errors.Not_found
              [%string "Macro expects %{Int.to_string fixed_count} arguments, got %{Int.to_string arg_count}"]));

  (* Bind fixed parameters *)
  let rec bind_fixed = function
    | ([], _) -> ()
    | (Fixed name :: rest_params, arg :: rest_args) ->
        Object.bind (name, arg, expansion_env) |> ignore;
        bind_fixed (rest_params, rest_args)
    | (Rest _ :: _, args) ->
        (* Rest parameter - bind remaining args as a list *)
        bind_rest args
    | _ ->
        raise (Errors.Runtime_error_exn (Errors.Not_found "Parameter binding error"))

  and bind_rest remaining_args =
    match remaining_args with
    | [] ->
        (* No rest arguments, bind to empty list *)
        ()
    | _ ->
        (* Find the rest parameter name *)
        let rest_name =
          match List.find param_specs ~f:(function Rest _ -> true | Fixed _ -> false) with
          | Some (Rest name) -> name
          | None -> raise (Errors.Runtime_error_exn (Errors.Not_found "Rest parameter not found"))
        in
        (* Create a list of remaining arguments *)
        let rest_list = Object.list_to_pair remaining_args in
        Object.bind (rest_name, rest_list, expansion_env) |> ignore

  in
    bind_fixed (param_specs, arg_sexprs)
```

**Step 2: Update expand_macro_call to use new binding logic**

Find `expand_macro_call` function (around line 231) and replace the parameter binding section:

```ocaml
let expand_macro_call macro_name args macro_env env =
  let macro_obj = Object.lookup (macro_name, env) in
    match macro_obj with
    | Object.Macro (_, param_specs, body_expr, _) ->  (* Changed: param_names -> param_specs *)
      let arg_sexprs = List.map ~f:expr_to_sexpr args in
      let expansion_env = Object.extend_env macro_env in

      (** Use new variadic-aware parameter binding *)
      let () = bind_macro_params param_specs arg_sexprs expansion_env in

      body_expr
    | _ ->
      raise
        (Errors.Runtime_error_exn
           (Errors.Not_found [%string "%{macro_name} is not a macro"]))
```

**Step 3: Update expand_expr macro call case**

Find the macro call case in `expand_expr` (around line 403) and update it:

```ocaml
  | Object.Call (Object.Var fn_name, args) when is_macro fn_name env ->
    let macro_obj = Object.lookup (fn_name, env) in
      match macro_obj with
      | Object.Macro (_, param_specs, body_expr, macro_env) ->
        let arg_sexprs = List.map ~f:expr_to_sexpr args in
        let expansion_env = Object.extend_env macro_env in

        (** Use new variadic-aware parameter binding *)
        let () = bind_macro_params param_specs arg_sexprs expansion_env in

        let result_sexpr =
          match eval_fn body_expr expansion_env with
          | Object.Quote sexpr ->
            sexpr
          | sexpr ->
            sexpr
        in

        let expanded_expr = Ast.build_ast result_sexpr in
          expand_expr expanded_expr env ~eval_fn ~depth:(depth + 1)

      | _ ->
        expr
```

**Step 4: Update expand_1_expr macro call case**

Find the macro call case in `expand_1_expr` (around line 745) and update it similarly:

```ocaml
  | Object.Call (Object.Var fn_name, args) when is_macro fn_name env ->
    let macro_obj = Object.lookup (fn_name, env) in
      (match macro_obj with
       | Object.Macro (_, param_specs, body_expr, macro_env) ->
           let arg_sexprs = List.map ~f:expr_to_sexpr args in
           let expansion_env = Object.extend_env macro_env in

           (** Use new variadic-aware parameter binding *)
           let () = bind_macro_params param_specs arg_sexprs expansion_env in

           let result_sexpr =
             match eval_fn body_expr expansion_env with
             | Object.Quote sexpr ->
               sexpr
             | sexpr ->
               sexpr
           in

           let expanded_expr = Ast.build_ast result_sexpr in
             (expanded_expr, true)

       | _ ->
         (expr, false))
```

**Step 5: Build and verify**

Run: `dune build`
Expected: SUCCESS - all type errors resolved

**Step 6: Commit**

```bash
git add lib/object/object.ml lib/ast/ast.ml lib/macro/macro.ml
git commit -m "feat(macro): add &rest parameter support for variadic macros"
```

---

## Task 8: Write Tests for Variadic Macros

**Files:**
- Create: `test/54_variadic_macros.mlisp`

**Step 1: Write the test file**

```lisp
;; Test variadic macros with &rest parameter

;; Test 1: Basic &rest macro - pack all arguments
(print "Test 1: Basic &rest macro")
(defmacro list-all (&rest args)
  `(quote ,args))
(define result1 (list-all 1 2 3 4 5))
(print result1)
(assert (== result1 (quote (1 2 3 4 5))))

;; Test 2: Mixed fixed and rest parameters
(print "Test 2: Fixed + rest parameters")
(defmacro with-fixed (first second &rest rest)
  `(quote (,first ,second ,@rest)))
(define result2 (with-fixed 1 2 3 4))
(print result2)
(assert (== result2 (quote (1 2 3 4))))

;; Test 3: &rest with no extra arguments (empty list)
(print "Test 3: &rest with no extra arguments")
(define result3 (with-fixed 1 2))
(print result3)
(assert (== result3 (quote (1 2))))

;; Test 4: Single rest argument
(print "Test 4: Single rest argument")
(define result4 (with-fixed 1 2 3))
(print result4)
(assert (== result4 (quote (1 2 3))))

;; Test 5: Using &rest with unquote-splicing
(print "Test 5: &rest with unquote-splicing")
(defmacro wrap-with-list (name &rest body)
  `(quote (,name ,@body)))
(define result5 (wrap-with-list my-function a b c))
(print result5)
(assert (== result5 (quote (my-function a b c))))

;; Test 6: Nested macro with &rest
(print "Test 6: Nested macro with &rest")
(defmacro outer (&rest args)
  `(list-all ,@args))
(define result6 (outer x y z))
(print result6)
(assert (== result6 (quote (x y z))))

;; Test 7: Error case - &rest not last parameter (should fail at parse time)
;; This test is commented out - it should cause a parse error
;; (defmacro invalid (&rest rest another) `(quote ,rest))

;; Test 8: Create an ocall macro using variadic parameters
(print "Test 8: Dynamic ocall using &rest")
(defmacro ocall (mod method &rest args)
  `((record-get ,mod (quote ,method)) ,@args))
(define test-list (quote (1 2 3)))
(define result8 (ocall List (quote length) test-list))
(print result8)
(assert (= result8 3))

;; Test 9: Multiple arities with same macro
(print "Test 9: Single argument through &rest")
(define result9 (list-all only-one))
(print result9)
(assert (== result9 (quote (only-one))))

;; Test 10: No arguments through &rest
(print "Test 10: No arguments")
(define result10 (list-all))
(print result10)
(assert (== result10 (quote ())))

(print "All variadic macro tests passed!")
```

**Step 2: Run the test**

Run: `dune exec mlisp -- test/54_variadic_macros.mlisp`
Expected: All tests pass, "All variadic macro tests passed!" printed

**Step 3: Commit**

```bash
git add test/54_variadic_macros.mlisp
git commit -m "test: add comprehensive variadic macro tests"
```

---

## Task 9: Update ocaml.mlisp Stdlib to Use Variadic Macro

**Files:**
- Modify: `stdlib/ocaml.mlisp`

**Step 1: Replace ocall1/2/3 with single ocall macro**

Replace the entire file content:

```lisp
;; OCaml Standard Library Bindings - Syntax Sugar
;; This module provides convenient syntax for accessing OCaml stdlib functions

;; Macro: ocall operator for module methods with variable arguments
;; (ocall mod method arg1 arg2 ...) expands to ((record-get mod (quote method)) arg1 arg2 ...)
(defmacro ocall (mod method &rest args)
  `((record-get ,mod (quote ,method)) ,@args))

;; Note: The ocall macro handles any number of arguments,
;; replacing the previous ocall1, ocall2, ocall3 macros.
```

**Step 2: Update test file to use new ocall syntax**

**Step 3: Run existing tests**

Run: `dune exec mlisp -- test/53_syntax_sugar.mlisp`
Expected: Tests still pass (backward compatible if we keep ocall1/2/3, or update tests)

**Step 4: Commit**

```bash
git add stdlib/ocaml.mlisp test/53_syntax_sugar.mlisp
git commit -m "feat(stdlib): replace ocall1/2/3 with single variadic ocall macro"
```

---

## Task 10: Update Documentation

**Files:**
- Modify: `README.md`

**Step 1: Add &rest macro documentation to Macros section**

Find the Macros section (around line 392) and add after "Hygienic Macros with Gensym":

```lisp
### Variadic Macros with &rest

Macros can accept variable numbers of arguments using the `&rest` parameter. The `&rest` parameter collects any remaining arguments into a list:

```lisp
;; Macro that collects all arguments
(defmacro list-all (&rest args)
  `(quote ,args))

(list-all 1 2 3 4)      ;; (1 2 3 4)

;; Fixed parameters followed by rest parameter
(defmacro with-fixed (first second &rest rest)
  `(quote (,first ,second ,@rest)))

(with-fixed 1 2 3 4)    ;; (1 2 3 4)
(with-fixed 1 2)        ;; (1 2) - rest is empty list
```

The `&rest` parameter must be the last parameter in the parameter list. Any arguments beyond the fixed parameters are packed into a list and bound to the rest parameter name.

This is especially useful for creating generic wrapper macros:

```lisp
;; Generic OCaml function call macro
(defmacro ocall (mod method &rest args)
  `((record-get ,mod (quote ,method)) ,@args))

(ocall String length "hello")      ;; 5
(ocall String concat "hello" " world")  ;; "hello world"
(ocall List length '(1 2 3))       ;; 3
```
```

**Step 2: Update OCaml Standard Library Bindings section**

Find the OCaml section (around line 600) and update the macro syntax section to use the new variadic `ocall`:

```lisp
#### Using Variadic Macro (ocall)

The `ocall` macro handles any number of arguments:

```lisp
;; Single argument
(ocall String length "hello")      ;; 5

;; Two arguments
(ocall String concat "hello" " world")  ;; "hello world"

;; Three arguments
(ocall String sub "hello" 1 3)     ;; "ell"

;; More arguments as needed
(ocall YourModule your-method arg1 arg2 arg3 arg4 ...)
```
```

**Step 3: Run full test suite**

Run: `./run_tests.sh`
Expected: All tests pass

**Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add variadic macro (&rest) documentation"
```

---

## Task 11: Run Full Test Suite and Verify

**Files:**
- Test: All test files

**Step 1: Run full test suite**

Run: `./run_tests.sh -v`
Expected: All 43+ tests pass (including new variadic macro test)

**Step 2: Test REPL manually**

Run: `dune exec mlisp`

Try these expressions in the REPL:

```lisp
(defmacro test (&rest args) `(quote ,args))
(test 1 2 3)
;; Expected: (1 2 3)

(defmacro mixed (a b &rest c) `(quote (,a ,b ,@c)))
(mixed 1 2 3 4 5)
;; Expected: (1 2 3 4 5)
```

**Step 3: Check for any edge cases**

- Empty rest: `(test)` should work
- Only fixed params: `(mixed 1 2)` should work
- Many rest args: `(mixed 1 2 3 4 5 6 7 8 9 10)` should work

**Step 4: Final commit if needed**

```bash
git commit --allow-empty -m "feat: variadic macro implementation complete"
```

---

## Summary of Changes

1. **lib/object/object.ml**: Added `RestParam` variant and `param_spec` type
2. **lib/ast/ast.ml**: Updated parameter parsing to recognize `&rest` syntax
3. **lib/macro/macro.ml**: Added variadic-aware parameter binding logic
4. **stdlib/ocaml.mlisp**: Simplified using variadic `ocall` macro
5. **test/54_variadic_macros.mlisp**: Comprehensive test coverage
6. **README.md**: Documentation updates

## Implementation Notes

- **Backward Compatibility**: The `ocall1/2/3` macros can be kept for compatibility or removed in favor of the single `ocall` macro
- **Lambda/defun**: These don't support `&rest` yet - that's a separate feature. The implementation intentionally raises an error.
- **Error Messages**: Clear error messages for `&rest` in wrong position or duplicate names
- **Testing**: 10 test cases covering edge cases like empty rest, single argument, nesting, etc.
