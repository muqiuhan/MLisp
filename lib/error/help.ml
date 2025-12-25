(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Errors

let help = function
  | Syntax_error_exn e -> (
    match e with
    | Unexcepted_character _ ->
      "Usually triggered by wrong characters, such as extra parentheses, etc."
    | Invalid_define_expression _ ->
      "(declare-expr symbol-name (formals) body)"
    | Invalid_boolean_literal _ ->
      "Raised by incorrect boolean literals."
    | Record_field_name_must_be_a_symbol record_name ->
      [%string "(:: '%{record_name} (@ (| 'field-name field-value)))"]
    | Illegal_if_expression _ ->
      "The return value of the conditional expression must be bool")
  | Parse_error_exn e -> (
    match e with
    | Unique_error _ ->
      "A conflict error caused by duplicate parameter names when defining closure."
    | Type_error _ ->
      "Possible type error due to a function call with parameters of a type different \
       from that specified in the function definition."
    | Poorly_formed_expression ->
      "Syntactically incorrect or redundant elements."
    | Apply_error v ->
      [%string "'%{v}' may not be a function"])
  | Runtime_error_exn e -> (
    match e with
    | Not_found _ ->
      "Accessing an identifier that has not been defined in the context."
    | Unspecified_value _ ->
      "Accessing an identifier that is not explicitly defined in the context."
    | Missing_argument _ ->
      "It is possible that the actual parameter quantity is inconsistent with the formal \
       parameter quantity"
    | Non_definition_in_stdlib _ ->
      "Can only have definitions in stdlib"
    | Not_a_module _ ->
      "The symbol is not bound to a module object. Use (module ...) to define a module."
    | Export_not_found _ ->
      "The specified symbol is not exported by the module. Check the module's export list."
    | Module_load_error _ ->
      "Failed to load module from file. Check file path and module syntax.")
  | _ ->
    "None"
;;
