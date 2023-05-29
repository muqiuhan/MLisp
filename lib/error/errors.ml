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

type parse_error =
  | Unique_error of string
  | Type_error of string
  | Poorly_formed_expression
  | Apply_error of string

type syntax_error =
  | Invalid_boolean_literal of string
  | Unexcepted_character of string

type runtime_error =
  | Not_found of string
  | Unspecified_value of string
  | Missing_argument of string list

exception This_can't_happen_exn
exception Undefined_symbol_exn of string
exception Parse_error_exn of parse_error
exception Syntax_error_exn of syntax_error
exception Runtime_error_exn of runtime_error
