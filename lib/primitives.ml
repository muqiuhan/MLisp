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

open Types.Ast
open Types.Object

let rec list = function [] -> Nil | car :: cdr -> Pair (car, list cdr)

let pair = function
  | [ a; b ] -> Pair (a, b)
  | _ -> raise (Parse_error_exn (Type_error "(pair a b)"))

let car = function
  | [ Pair (car, _) ] -> car
  | _ -> raise (Parse_error_exn (Type_error "(car non-nil-pair)"))

let cdr = function
  | [ Pair (_, cdr) ] -> cdr
  | _ -> raise (Parse_error_exn (Type_error "(cdr non-nil-pair)"))

let atomp = function
  | [ Pair (_, _) ] -> Boolean false
  | [ _ ] -> Boolean true
  | _ -> raise (Parse_error_exn (Type_error "(atom? something)"))

let eq = function
  | [ a; b ] -> Boolean (a = b)
  | _ -> raise (Parse_error_exn (Type_error "(eq a b)"))

let symp = function
  | [ Symbol _ ] -> Boolean true
  | [ _ ] -> Boolean false
  | _ -> raise (Parse_error_exn (Type_error "(sym? single-arg)"))

let getchar = function
  | [] -> (
      try Fixnum (int_of_char @@ input_char stdin)
      with End_of_file -> Fixnum (-1))
  | _ -> raise (Parse_error_exn (Type_error "(getchar)"))

let print = function
  | [ v ] ->
      let () = print_string @@ Object.string_object v in
      Symbol "ok"
  | _ -> raise (Parse_error_exn (Type_error "(print object)"))

let int_to_char = function
  | [ Fixnum i ] -> Symbol (Object.string_of_char @@ char_of_int i)
  | _ -> raise (Parse_error_exn (Type_error "(int_to_char int)"))

let cat = function
  | [ Symbol a; Symbol b ] -> Symbol (a ^ b)
  | _ -> raise (Parse_error_exn (Type_error "(cat sym sym)"))

module Num = struct
  let generate name operator =
    ( name,
      function
      | [ Fixnum a; Fixnum b ] -> Fixnum (operator a b)
      | _ -> raise (Parse_error_exn (Type_error ("(" ^ name ^ " int int)"))) )
end

module Cmp = struct
  let generate name operator =
    ( name,
      function
      | [ Fixnum a; Fixnum b ] -> Boolean (operator a b)
      | _ -> raise (Parse_error_exn (Type_error ("(" ^ name ^ " int int)"))) )
end
