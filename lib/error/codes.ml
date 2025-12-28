(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Errors

(** Error code system for MLisp.

    Each error type is assigned a unique error code following the pattern:
    - E001-E099: Parse errors
    - E100-E199: Syntax errors
    - E200-E299: Runtime errors

    This allows for better error categorization and documentation. *)

(** Get error code for an exception.

    Returns the error code string (e.g., "E001") for the given exception,
    or None if the exception type is not recognized.

    @param exn Exception to get error code for
    @return Optional error code string *)
let error_code = function
  | Parse_error_exn e -> (
    match e with
    | Unique_error _ ->
      Some "E001"
    | Type_error _ ->
      Some "E002"
    | Poorly_formed_expression ->
      Some "E003"
    | Apply_error _ ->
      Some "E004")
  | Syntax_error_exn e -> (
    match e with
    | Unexcepted_character _ ->
      Some "E100"
    | Invalid_boolean_literal _ ->
      Some "E101"
    | Invalid_define_expression _ ->
      Some "E102"
    | Record_field_name_must_be_a_symbol _ ->
      Some "E103"
    | Illegal_if_expression _ ->
      Some "E104")
  | Runtime_error_exn e -> (
    match e with
    | Not_found _ ->
      Some "E200"
    | Unspecified_value _ ->
      Some "E201"
    | Missing_argument _ ->
      Some "E202"
    | Non_definition_in_stdlib _ ->
      Some "E203"
    | Not_a_module _ ->
      Some "E204"
    | Export_not_found _ ->
      Some "E205"
    | Module_load_error _ ->
      Some "E206")
  | _ ->
    None
;;
