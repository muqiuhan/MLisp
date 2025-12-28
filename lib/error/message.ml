(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Errors
open Mlisp_utils

(** Generate error message with unified format.

    All error messages follow the format: "Error type: details"
    This ensures consistency across all error types.

    @param exn Exception to generate message for
    @return Formatted error message string *)
let message = function
  | Syntax_error_exn e -> (
    match e with
    | Unexcepted_character c ->
      [%string "Unexpected character: '%{c}'"]
    | Invalid_boolean_literal b ->
      [%string "Invalid boolean literal: '%{b}'"]
    | Record_field_name_must_be_a_symbol record_name ->
      [%string "Record field name must be a symbol: %{record_name}"]
    | Invalid_define_expression e ->
      [%string "Invalid define expression: '%{e}'"]
    | Illegal_if_expression expr ->
      [%string "Illegal if expression: %{expr}"])
  | Parse_error_exn e -> (
    match e with
    | Unique_error p ->
      [%string "Unique error: %{p}"]
    | Type_error x ->
      [%string "Type error: %{x}"]
    | Poorly_formed_expression ->
      "Poorly formed expression"
    | Apply_error v ->
      [%string
        "Apply error: '%{v}' may not be a function. Use (>> %{v} '(args)) or (%{v} args)"]
    )
  | Runtime_error_exn e -> (
    match e with
    | Not_found e ->
      [%string "Not found: %{e}"]
    | Unspecified_value e ->
      [%string "Unspecified value: %{e}"]
    | Missing_argument args ->
      [%string "Missing arguments: %{String.spacesep args}"]
    | Non_definition_in_stdlib expr ->
      [%string "Non-definition in stdlib: %{expr}"]
    | Not_a_module name ->
      [%string "Not a module: %{name}"]
    | Export_not_found (mod_name, export_name) ->
      [%string "Export not found: '%{export_name}' in module '%{mod_name}'"]
    | Module_load_error (mod_name, reason) ->
      [%string "Module load error: '%{mod_name}' - %{reason}"])
  | exn ->
    raise exn
;;
