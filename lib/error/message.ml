(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Errors
open Mlisp_utils

let message = function
  | Syntax_error_exn e -> begin
    match e with
    | Unexcepted_character c -> [%string "Unexcepted character : '%{c}'"]
    | Invalid_boolean_literal b -> [%string "Invalid boolean literal : '%{b}"]
    | Record_field_name_must_be_a_symbol record_name ->
      [%string "The record %{record_name} field name must be a symbol"]
    | Invalid_define_expression e ->
      [%string "Invalid define expression : '%{e}"]
  end
  | Parse_error_exn e -> begin
    match e with
    | Unique_error p -> [%string "Unique error : %{p}"]
    | Type_error x -> [%string "Type error : %{x}"]
    | Poorly_formed_expression -> "Poorly formed expression."
    | Apply_error v -> [%string "(>> %{v} '(args)) or (%{v} args)"]
  end
  | Runtime_error_exn e -> (
    match e with
    | Not_found e -> [%string "Not found : %{e}"]
    | Unspecified_value e -> [%string "Unspecified value : %{e}"]
    | Missing_argument args ->
      [%string "Missing arguments : %{String.spacesep args}"]
    | Non_definition_in_stdlib expr ->
      [%string "This expression is not a defining expression: %{expr}"])
  | exn -> raise exn
;;
