(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Errors
open Mlisp_utils

let message = function
  | Syntax_error_exn e -> (
    "Syntax error -> "
    ^
    match e with
    | Unexcepted_character c -> "Unexcepted character : '" ^ c ^ "'"
    | Invalid_boolean_literal b -> "Invalid boolean literal : '" ^ b ^ "'"
    | Record_field_name_must_be_a_symbol record_name ->
      Format.sprintf "The record %s field name must be a symbol" record_name
    | Invalid_define_expression e -> "Invalid define expression : '" ^ e ^ "'")
  | Parse_error_exn e -> (
    "Parse error -> "
    ^
    match e with
    | Unique_error p -> "Unique error : " ^ p
    | Type_error x -> "Type error : " ^ x
    | Poorly_formed_expression -> "Poorly formed expression."
    | Apply_error v -> Format.sprintf "(apply %s '(args)) or (%s args)" v v)
  | Runtime_error_exn e -> (
    match e with
    | Not_found e -> "Not found : " ^ e
    | Unspecified_value e -> "Unspecified value : " ^ e
    | Missing_argument args -> "Missing arguments : " ^ String.spacesep args)
  | _ -> "None"
;;
