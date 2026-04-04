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
let require_list = Mlisp_primitives__Validate.require_list
let check_int_range = Mlisp_primitives__Validate.check_int_range

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
           (Errors.Value_error
              ( "String.sub"
              , [%string
                  "substring out of bounds (string length: %{Int.to_string s_len}, \
                   requested: %{Int.to_string pos} + %{Int.to_string len})"] )))
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
let list_length args =
  check_arg_count "List.length" args 1;
  let lst = require_list "List.length" "list" (List.hd_exn args) in
    Object.Fixnum (List.length lst)
;;

(** List append - concatenates two lists.
    (List.append '(1 2) '(3 4)) -> (1 2 3 4) *)
let list_append args =
  check_arg_count "List.append" args 2;
  let list1 = require_list "List.append" "first" (List.nth_exn args 0) in
  let list2 = require_list "List.append" "second" (List.nth_exn args 1) in
    Object.list_to_pair (list1 @ list2)
;;

(** List reverse - reverses a list.
    (List.rev '(1 2 3)) -> (3 2 1) *)
let list_rev args =
  check_arg_count "List.rev" args 1;
  let lst = require_list "List.rev" "list" (List.hd_exn args) in
    Object.list_to_pair (List.rev lst)
;;

(** List nth - gets element at index (0-based).
    (List.nth '(1 2 3) 1) -> 2 *)
let list_nth args =
  check_arg_count "List.nth" args 2;
  let lst = require_list "List.nth" "list" (List.nth_exn args 0) in
  let idx = require_int "List.nth" "index" (List.nth_exn args 1) in
  (* Validate index bounds *)
  let lst_len = List.length lst in
    if idx < 0 then
      raise
        (Errors.Runtime_error_exn
           (Errors.Value_error ("List.nth", "index must be non-negative")))
    else if idx >= lst_len then
      raise
        (Errors.Runtime_error_exn
           (Errors.Value_error
              ( "List.nth"
              , [%string
                  "index out of bounds (list length: %{Int.to_string lst_len}, index: \
                   %{Int.to_string idx})"] )))
    else
      List.nth_exn lst idx
;;

(** List membership check - tests if element is in list using = comparison.
    (List.mem 2 '(1 2 3)) -> #t *)
let list_mem args =
  check_arg_count "List.mem" args 2;
  let elem = List.nth_exn args 0 in
  let lst = require_list "List.mem" "list" (List.nth_exn args 1) in
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
;;

(** List flatten - flattens one level of nesting.
    (List.flatten '((1 2) (3 4))) -> (1 2 3 4) *)
let list_flatten args =
  check_arg_count "List.flatten" args 1;
  let lst = require_list "List.flatten" "list-of-lists" (List.hd_exn args) in
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
;;

(** List concat - concatenates a list of lists.
    (List.concat '((1 2) (3 4) (5))) -> (1 2 3 4 5) *)
let list_concat args =
  check_arg_count "List.concat" args 1;
  let lst = require_list "List.concat" "list-of-lists" (List.hd_exn args) in
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
;;

(** List sort - sorts a list of numbers in ascending order.
    (List.sort '(3 1 2)) -> (1 2 3) *)
let list_sort args =
  check_arg_count "List.sort" args 1;
  let lst = require_list "List.sort" "list" (List.hd_exn args) in
  let extract_fixnum = function
    | Object.Fixnum n ->
      Int.to_int_exn n
    | _ ->
      raise
        (Errors.Runtime_error_exn
           (Errors.Argument_type_error ("List.sort", "element", "number")))
  in
  let fixnum_list = List.map lst ~f:extract_fixnum in
  let sorted = List.sort ~compare:Int.compare fixnum_list in
    Object.list_to_pair (List.map sorted ~f:(fun n -> Object.Fixnum (Int.of_int n)))
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

(** OCaml File module bindings.

    Provides file I/O operations using OCaml's In_channel and Out_channel. *)

(** File.read-all - reads entire file contents as string.
    (File.read-all "filename") -> string contents
    Raises error if file cannot be read. *)
let file_read_all args =
  check_arg_count "File.read-all" args 1;
  let fname = require_string "File.read-all" "filename" (List.hd_exn args) in
    try
      Object.String (In_channel.read_all fname)
    with Sys_error msg ->
      raise (Errors.Runtime_error_exn
               (Errors.Value_error ("File.read-all", "cannot read file: " ^ msg)))

(** File.write - writes string to file (overwrites existing).
    (File.write "filename" "content") -> ok
    Raises error if file cannot be written. *)
let file_write args =
  check_arg_count "File.write" args 2;
  let fname = require_string "File.write" "filename" (List.nth_exn args 0) in
  let content = require_string "File.write" "content" (List.nth_exn args 1) in
    try
      Out_channel.write_all fname ~data:content;
      Object.Symbol "ok"
    with Sys_error msg ->
      raise (Errors.Runtime_error_exn
               (Errors.Value_error ("File.write", "cannot write file: " ^ msg)))

(** File.exists? - checks if file exists.
    (File.exists? "filename") -> #t or #f *)
let file_exists args =
  check_arg_count "File.exists?" args 1;
  let fname = require_string "File.exists?" "filename" (List.hd_exn args) in
    Object.Boolean (Stdlib.Sys.file_exists fname)

(** File.read-lines - reads file as list of lines.
    (File.read-lines "filename") -> ("line1" "line2" ...)
    Raises error if file cannot be read. *)
let file_read_lines args =
  check_arg_count "File.read-lines" args 1;
  let fname = require_string "File.read-lines" "filename" (List.hd_exn args) in
    try
      let lines = In_channel.read_lines fname in
        Object.list_to_pair (List.map lines ~f:(fun s -> Object.String s))
    with Sys_error msg ->
      raise (Errors.Runtime_error_exn
               (Errors.Value_error ("File.read-lines", "cannot read file: " ^ msg)))
;;

(** Create the File module with all bindings. *)
let file_module =
  make_module
    "File"
    [ "read-all", file_read_all
    ; "write", file_write
    ; "exists?", file_exists
    ; "read-lines", file_read_lines
    ]
;;

(** OCaml Array module bindings.

    Provides operations on fixed-size arrays. *)

(** Array.make - creates a new array with given size and fill value.
    (Array.make size fill) -> array *)
let array_make args =
  check_arg_count "Array.make" args 2;
  let size = require_int "Array.make" "size" (List.nth_exn args 0) in
  let fill = List.nth_exn args 1 in
    if size < 0 then
      raise (Errors.Runtime_error_exn
               (Errors.Value_error ("Array.make", "size must be non-negative")))
    else
      Object.Array (Stdlib.Array.make size fill)
;;

(** Array.get - gets element at index.
    (Array.get arr index) -> element
    Raises error if index out of bounds. *)
let array_get args =
  check_arg_count "Array.get" args 2;
  match List.nth_exn args 0 with
  | Object.Array arr ->
    let idx = require_int "Array.get" "index" (List.nth_exn args 1) in
      if idx < 0 || idx >= Stdlib.Array.length arr then
        raise (Errors.Runtime_error_exn
                 (Errors.Value_error ("Array.get", "index out of bounds")))
      else
        arr.(idx)
  | _ ->
    raise (Errors.Runtime_error_exn
             (Errors.Argument_type_error ("Array.get", "array", "array")))
;;

(** Array.set - sets element at index.
    (Array.set arr index value) -> ok
    Raises error if index out of bounds. *)
let array_set args =
  check_arg_count "Array.set" args 3;
  match List.nth_exn args 0 with
  | Object.Array arr ->
    let idx = require_int "Array.set" "index" (List.nth_exn args 1) in
      if idx < 0 || idx >= Stdlib.Array.length arr then
        raise (Errors.Runtime_error_exn
                 (Errors.Value_error ("Array.set", "index out of bounds")))
      else (
        arr.(idx) <- List.nth_exn args 2;
        Object.Symbol "ok"
      )
  | _ ->
    raise (Errors.Runtime_error_exn
             (Errors.Argument_type_error ("Array.set", "array", "array")))
;;

(** Array.length - returns array length.
    (Array.length arr) -> fixnum *)
let array_length args =
  check_arg_count "Array.length" args 1;
  match List.hd_exn args with
  | Object.Array arr -> Object.Fixnum (Int.of_int (Stdlib.Array.length arr))
  | _ ->
    raise (Errors.Runtime_error_exn
             (Errors.Argument_type_error ("Array.length", "array", "array")))
;;

(** Array.to-list - converts array to list.
    (Array.to-list arr) -> list *)
let array_to_list_prim args =
  check_arg_count "Array.to-list" args 1;
  match List.hd_exn args with
  | Object.Array arr -> Object.array_to_list arr
  | _ ->
    raise (Errors.Runtime_error_exn
             (Errors.Argument_type_error ("Array.to-list", "array", "array")))
;;

(** Create the Array module with all bindings. *)
let array_module =
  make_module
    "Array"
    [ "make", array_make
    ; "get", array_get
    ; "set", array_set
    ; "length", array_length
    ; "to-list", array_to_list_prim
    ]
;;

(** Basis bindings for OCaml standard library modules.

    Returns a list of (name, lobject) pairs suitable for binding
    in the base environment. Each binding creates a Record object
    containing the module's functions as fields, accessible via record-get.

    Example: (record-get String "length" "hello") -> 5 *)
let basis = [ "String", string_module; "List", list_module; "File", file_module; "Array", array_module ]
