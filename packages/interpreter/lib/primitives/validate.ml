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
        (Errors.Runtime_error_exn (Errors.Argument_count_error (func_name, expected, got)))
;;

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
;;

(** Validate that an argument is a String.

    @param func_name Name of the function (for error messages)
    @param param_name Name of the parameter (for error messages)
    @param value The argument value to check
    @return The string value if valid
    @raise Runtime_error_exn if not a String
*)
let require_string func_name param_name = function
  | Object.String s ->
    s
  | _ ->
    let expected_type = "string" in
      raise
        (Errors.Runtime_error_exn
           (Errors.Argument_type_error (func_name, param_name, expected_type)))
;;

(** Validate that an argument is a Fixnum.

    @param func_name Name of the function
    @param param_name Name of the parameter
    @param value The argument value to check
    @return The integer value if valid
    @raise Runtime_error_exn if not a Fixnum
*)
let require_int func_name param_name = function
  | Object.Fixnum n ->
    Int.to_int_exn n
  | _ ->
    raise
      (Errors.Runtime_error_exn
         (Errors.Argument_type_error (func_name, param_name, "integer")))
;;

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
  | _ ->
    raise
      (Errors.Runtime_error_exn
         (Errors.Argument_type_error (func_name, param_name, "number")))
;;

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
  | _ ->
    raise
      (Errors.Runtime_error_exn
         (Errors.Argument_type_error (func_name, param_name, "list")))
;;

(** Check that an integer is within a range.

    @param func_name Name of the function
    @param param_name Name of the parameter
    @param value The integer value to check
    @param min_value Minimum allowed value (inclusive)
    @param max_value Maximum allowed value (inclusive), or None for no max
    @return The value if valid
    @raise Runtime_error_exn if out of range
*)
let check_int_range func_name param_name value ?(min_value = None) ?(max_value = None) () =
  let check_min =
    min_value |> Option.value_map ~default:true ~f:(fun min -> value >= min)
  in
  let check_max =
    max_value |> Option.value_map ~default:true ~f:(fun max -> value <= max)
  in
    if not (check_min && check_max) then (
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
    ) else
      value
;;
