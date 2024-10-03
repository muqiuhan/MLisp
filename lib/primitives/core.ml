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

open Mlisp_object
open Mlisp_error

let rec list = function
  | [] -> Object.Nil
  | car :: cdr -> Object.Pair (car, list cdr)

let pair = function
  | [a; b] -> Object.Pair (a, b)
  | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(pair a b)"))

let car = function
  | [Object.Pair (car, _)] -> car
  | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(car non-nil-pair)"))

let cdr = function
  | [Object.Pair (_, cdr)] -> cdr
  | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(cdr non-nil-pair)"))

let atomp = function
  | [Object.Pair (_, _)] -> Object.Boolean false
  | [_] -> Object.Boolean true
  | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(atom? something)"))

let eq = function
  | [a; b] -> Object.Boolean (a = b)
  | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(eq a b)"))

let symp = function
  | [Object.Symbol _] -> Object.Boolean true
  | [_] -> Object.Boolean false
  | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(sym? single-arg)"))

let getchar = function
  | [] -> (
    try Object.Fixnum (int_of_char @@ input_char stdin)
    with End_of_file -> Object.Fixnum (-1))
  | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(getchar)"))

let print = function
  | [v] ->
    let () = print_string @@ Object.string_object v in
      Object.Symbol "ok"
  | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(print object)"))

let int_to_char = function
  | [Object.Fixnum i] -> Object.Symbol (Object.string_of_char @@ char_of_int i)
  | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(int_to_char int)"))

let cat = function
  | [Object.Symbol a; Object.Symbol b] -> Object.Symbol (a ^ b)
  | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(cat sym sym)"))
