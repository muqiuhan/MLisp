(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core

(* Use Validate functions through fully qualified name *)
let check_arg_count = Mlisp_primitives__Validate.check_arg_count
let require_string = Mlisp_primitives__Validate.require_string
let require_int = Mlisp_primitives__Validate.require_int

(** Helper function to create a module Record from bindings.

    Creates a MLisp Record object containing all bindings as fields.
    Functions are stored as Primitive objects.

    @param name Module name for use in MLisp
    @param bindings List of (name, function) pairs
    @return A MLisp Record lobject *)
let make_module name bindings =
  List.map bindings ~f:(fun (binding_name, func) ->
    binding_name, Object.Primitive (binding_name, func))
  |> fun fields -> Object.Record (name, fields)
;;

(** OCaml String module bindings.

    Provides MLisp access to OCaml's standard library String functions. *)

(** String length - returns the length of a string as Fixnum.
    (String.length "hello") -> 5 *)
let string_length args =
  check_arg_count "String.length" args 1;
  let s = require_string "String.length" "string" (List.hd_exn args) in
  Object.Fixnum (String.length s)
;;

(** String concatenation - joins two strings.
    (String.concat "hello" "world") -> "helloworld" *)
let string_concat args =
  check_arg_count "String.concat" args 2;
  let s1 = require_string "String.concat" "first" (List.nth_exn args 0) in
  let s2 = require_string "String.concat" "second" (List.nth_exn args 1) in
  Object.String (s1 ^ s2)
;;

(** String split - splits a string by separator, returns Lisp list.
    (String.split "a,b,c" ",") -> ("a" "b" "c")
    Note: Supports single-character separators only. *)
let string_split args =
  check_arg_count "String.split" args 2;
  let s = require_string "String.split" "string" (List.nth_exn args 0) in
  let sep = require_string "String.split" "separator" (List.nth_exn args 1) in
  (* Core's String.split takes a char; use first char of separator *)
  let sep_char =
    if String.length sep > 0 then
      String.get sep 0
    else
      ','
  in
  let parts = String.split ~on:sep_char s in
    Object.list_to_pair (List.map parts ~f:(fun p -> Object.String p))
;;

(** Uppercase conversion - converts string to uppercase.
    (String.upper "hello") -> "HELLO" *)
let string_upper args =
  check_arg_count "String.upper" args 1;
  let s = require_string "String.upper" "string" (List.hd_exn args) in
  Object.String (String.uppercase s)
;;

(** Lowercase conversion - converts string to lowercase.
    (String.lower "HELLO") -> "hello" *)
let string_lower args =
  check_arg_count "String.lower" args 1;
  let s = require_string "String.lower" "string" (List.hd_exn args) in
  Object.String (String.lowercase s)
;;

(** Substring - extracts substring starting at position with given length.
    (String.sub "hello" 1 3) -> "ell" *)
let string_sub args =
  check_arg_count "String.sub" args 3;
  let s = require_string "String.sub" "string" (List.nth_exn args 0) in
  let pos = require_int "String.sub" "pos" (List.nth_exn args 1) in
  let len = require_int "String.sub" "len" (List.nth_exn args 2) in
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
;;

(** Contains check - tests if pattern is contained in string.
    (String.contains? "hello" "ell") -> #t *)
let string_contains args =
  check_arg_count "String.contains?" args 2;
  let s = require_string "String.contains?" "string" (List.nth_exn args 0) in
  let pattern = require_string "String.contains?" "pattern" (List.nth_exn args 1) in
  Object.Boolean (String.is_substring ~substring:pattern s)
;;

(** Trim whitespace - strips leading and trailing whitespace.
    (String.trim "  hello  ") -> "hello" *)
let string_trim args =
  check_arg_count "String.trim" args 1;
  let s = require_string "String.trim" "string" (List.hd_exn args) in
  Object.String (String.strip s)
;;

(** Create the String module with all bindings. *)
let string_module =
  make_module
    "String"
    [ "length", string_length
    ; "concat", string_concat
    ; "split", string_split
    ; "upper", string_upper
    ; "lower", string_lower
    ; "sub", string_sub
    ; "contains?", string_contains
    ; "trim", string_trim
    ]
;;

(** OCaml List module bindings.

    Provides MLisp access to OCaml's standard library List functions.

    Note: Functions that take function arguments (map, filter, fold, etc.)
    are implemented in MLisp's standard library (list.mlisp) rather than
    as OCaml primitives, to avoid circular dependency issues.

    This module provides data-manipulation functions that operate on
    MLisp list structures. *)

(** List length - returns the length of a list as Fixnum.
    (List.length '(1 2 3)) -> 3 *)
let list_length = function
  | [ Object.Nil ] ->
    Object.Fixnum 0
  | [ Object.Pair _ ] as args ->
    Object.Fixnum (List.length (Object.pair_to_list (List.hd_exn args)))
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(List.length list)"))
;;

(** List append - concatenates two lists.
    (List.append '(1 2) '(3 4)) -> (1 2 3 4) *)
let list_append = function
  | [ lst1; lst2 ] ->
    let list1 = Object.pair_to_list lst1 in
    let list2 = Object.pair_to_list lst2 in
      Object.list_to_pair (list1 @ list2)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(List.append list list)"))
;;

(** List reverse - reverses a list.
    (List.rev '(1 2 3)) -> (3 2 1) *)
let list_rev = function
  | [ Object.Nil ] ->
    Object.Nil
  | [ Object.Pair _ ] as args ->
    let lst = Object.pair_to_list (List.hd_exn args) in
      Object.list_to_pair (List.rev lst)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(List.rev list)"))
;;

(** List nth - gets element at index (0-based).
    (List.nth '(1 2 3) 1) -> 2 *)
let list_nth = function
  | [ (Object.Pair _ as lst_obj); Object.Fixnum idx ] ->
    let lst = Object.pair_to_list lst_obj in
    let idx_int = Int.to_int_exn idx in
      if idx_int < 0 || idx_int >= List.length lst then
        raise
          (Errors.Parse_error_exn
             (Errors.Type_error "(List.nth list index) - index out of bounds"))
      else
        List.nth_exn lst idx_int
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(List.nth list index)"))
;;

(** List membership check - tests if element is in list using = comparison.
    (List.mem 2 '(1 2 3)) -> #t *)
let list_mem = function
  | [ _elem; Object.Nil ] ->
    Object.Boolean false
  | [ elem; Object.Pair _ ] as args ->
    let lst = Object.pair_to_list (List.hd_exn (List.tl_exn args)) in
    let result = ref false in
    let rec loop = function
      | [] ->
        ()
      | x :: rest ->
        if Stdlib.compare x elem = 0 then
          result := true
        else
          loop rest
    in
      loop lst;
      Object.Boolean !result
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(List.mem element list)"))
;;

(** List flatten - flattens one level of nesting.
    (List.flatten '((1 2) (3 4))) -> (1 2 3 4) *)
let list_flatten = function
  | [ Object.Nil ] ->
    Object.Nil
  | [ Object.Pair _ ] as args ->
    let lst = Object.pair_to_list (List.hd_exn args) in
    let rec flatten_aux acc = function
      | [] ->
        List.rev acc
      | (Object.Pair _ as pair) :: rest ->
        (* Reverse each inner list and prepend to acc, so final reversal gives correct order *)
        let pair_elems = List.rev (Object.pair_to_list pair) in
          flatten_aux (pair_elems @ acc) rest
      | _ :: rest ->
        (* skip non-list elements *)
        flatten_aux acc rest
    in
      Object.list_to_pair (flatten_aux [] lst)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(List.flatten list-of-lists)"))
;;

(** List concat - concatenates a list of lists.
    (List.concat '((1 2) (3 4) (5))) -> (1 2 3 4 5) *)
let list_concat = function
  | [ Object.Nil ] ->
    Object.Nil
  | [ Object.Pair _ ] as args ->
    let lst = Object.pair_to_list (List.hd_exn args) in
    let rec concat_aux acc = function
      | [] ->
        List.rev acc
      | (Object.Pair _ as pair) :: rest ->
        (* Reverse each inner list and prepend to acc, so final reversal gives correct order *)
        let pair_elems = List.rev (Object.pair_to_list pair) in
          concat_aux (pair_elems @ acc) rest
      | Object.Nil :: rest ->
        concat_aux acc rest
      | _ :: rest ->
        (* skip non-list elements *)
        concat_aux acc rest
    in
      Object.list_to_pair (concat_aux [] lst)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(List.concat list-of-lists)"))
;;

(** List sort - sorts a list of numbers in ascending order.
    (List.sort '(3 1 2)) -> (1 2 3) *)
let list_sort = function
  | [ Object.Nil ] ->
    Object.Nil
  | [ Object.Pair _ ] as args ->
    let lst = Object.pair_to_list (List.hd_exn args) in
    let extract_fixnum = function
      | Object.Fixnum n ->
        Int.to_int_exn n
      | _ ->
        raise
          (Errors.Parse_error_exn
             (Errors.Type_error "(List.sort list) - all elements must be numbers"))
    in
    let fixnum_list = List.map lst ~f:extract_fixnum in
    let sorted = List.sort ~compare:Int.compare fixnum_list in
      Object.list_to_pair (List.map sorted ~f:(fun n -> Object.Fixnum (Int.of_int n)))
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(List.sort list)"))
;;

(** Create the List module with all bindings. *)
let list_module =
  make_module
    "List"
    [ "length", list_length
    ; "append", list_append
    ; "rev", list_rev
    ; "nth", list_nth
    ; "mem", list_mem
    ; "flatten", list_flatten
    ; "concat", list_concat
    ; "sort", list_sort
    ]
;;

(** Basis bindings for OCaml standard library modules.

    Returns a list of (name, lobject) pairs suitable for binding
    in the base environment. Each binding creates a Record object
    containing the module's functions as fields, accessible via record-get.

    Example: (record-get String "length" "hello") -> 5 *)
let basis = [ "String", string_module; "List", list_module ]
