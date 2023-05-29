(****************************************************************************)
(* MLisp                                                                    *)
(* Copyright (C) 2022 Muqiu Han                                             *)
(*                                                                          *)
(* This program is free software: you can redistribute it and/or modify     *)
(* it under the terms of the GNU Affero General Public License as published *)
(* by the Free Software Foundation, either version 3 of the License, or     *)
(* (at your option) any later version.                                      *)
(*                                                                          *)
(* This program is distributed in the hope that it will be useful,          *)
(* but WITHOUT ANY WARRANTY; without even the implied warranty of           *)
(* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            *)
(* GNU Affero General Public License for more details.                      *)
(*                                                                          *)
(* You should have received a copy of the GNU Affero General Public License *)
(* along with this program.  If not, see <https://www.gnu.org/licenses/>.   *)
(****************************************************************************)

open Errors

let help = function
  | Syntax_error_exn e -> (
    match e with
    | Unexcepted_character _ ->
      "Usually triggered by wrong characters, such as extra parentheses, etc."
    | Invalid_boolean_literal _ -> "Raised by incorrect boolean literals.")
  | Parse_error_exn e -> (
    match e with
    | Unique_error _ ->
      "A conflict error caused by duplicate parameter names when defining \
       closure."
    | Type_error _ ->
      "Possible type error due to a function call with parameters of a type \
       different from that specified in the function definition."
    | Poorly_formed_expression ->
      "Syntactically incorrect or redundant elements.")
  | Runtime_error_exn e -> (
    match e with
    | Not_found _ ->
      "Accessing an identifier that has not been defined in the context."
    | Unspecified_value _ ->
      "Accessing an identifier that is not explicitly defined in the context."
    | Missing_argument _ ->
      "It is possible that the actual parameter quantity is inconsistent with \
       the formal parameter quantity")
  | _ -> "None"
