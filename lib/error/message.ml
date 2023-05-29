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
open Mlisp_utils

let message = function
  | Syntax_error_exn e -> (
    "Syntax error -> "
    ^
    match e with
    | Unexcepted_character c -> "Unexcepted character : '" ^ c ^ "'"
    | Invalid_boolean_literal b -> "Invalid boolean literal : '" ^ b ^ "'")
  | Parse_error_exn e -> (
    "Parse error -> "
    ^
    match e with
    | Unique_error p -> "Unique error : " ^ p
    | Type_error x -> "Type error : " ^ x
    | Poorly_formed_expression -> "Poorly formed expression.")
  | Runtime_error_exn e -> (
    match e with
    | Not_found e -> "Not found : " ^ e
    | Unspecified_value e -> "Unspecified value : " ^ e
    | Missing_argument args -> "Missing arguments : " ^ String.spacesep args)
  | _ -> "None"
