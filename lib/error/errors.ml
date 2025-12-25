(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

type parse_error =
  | Unique_error of string
  | Type_error of string
  | Poorly_formed_expression
  | Apply_error of string

type syntax_error =
  | Invalid_boolean_literal of string
  | Invalid_define_expression of string
  | Unexcepted_character of string
  | Record_field_name_must_be_a_symbol of string
  | Illegal_if_expression of string

type runtime_error =
  | Not_found of string
  | Unspecified_value of string
  | Missing_argument of string list
  | Non_definition_in_stdlib of string
  | Not_a_module of string
  | Export_not_found of string * string
  | Module_load_error of string * string

exception This_can't_happen_exn
exception Undefined_symbol_exn of string
exception Parse_error_exn of parse_error
exception Syntax_error_exn of syntax_error
exception Runtime_error_exn of runtime_error
