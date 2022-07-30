(****************************************************************************)
(* OCamLisp                                                                 *)
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

open Types.Object

let rec list = function
  | [] -> Nil
  | car :: cdr -> Pair (car, list cdr)
;;

let pair = function
  | [ a; b ] -> Pair (a, b)
  | _ -> raise (Type_error_exn "(pair a b)")
;;

let car = function
  | [ Pair (car, _) ] -> car
  | _ -> raise (Type_error_exn "(car non-nil-pair)")
;;

let cdr = function
  | [ Pair (_, cdr) ] -> cdr
  | _ -> raise (Type_error_exn "(cdr non-nil-pair)")
;;

let atomp = function
  | [ Pair (_, _) ] -> Boolean false
  | [ _ ] -> Boolean true
  | _ -> raise (Type_error_exn "(atom? something)")
;;

let eq = function
  | [ a; b ] -> Boolean (a = b)
  | _ -> raise (Type_error_exn "(eq a b)")
;;

let symp = function
  | [ Symbol _ ] -> Boolean true
  | [ _ ] -> Boolean false
  | _ -> raise (Type_error_exn "(sym? single-arg)")
;;

let getchar = function
  | [] ->
    (try Fixnum (int_of_char @@ input_char stdin) with
    | End_of_file -> Fixnum (-1))
  | _ -> raise (Type_error_exn "(getchar)")
;;

let print = function
  | [ v ] ->
    let () = print_string @@ Ast.string_object v in
    Symbol "ok"
  | _ -> raise (Type_error_exn "(print object)")
;;

let int_to_char = function
  | [ Fixnum i ] -> Symbol (Object.string_of_char @@ char_of_int i)
  | _ -> raise (Type_error_exn "(int_to_char int)")
;;

let cat = function
  | [ Symbol a; Symbol b ] -> Symbol (a ^ b)
  | _ -> raise (Type_error_exn "(cat sym sym)")
;;

module Num = struct
  let generate name operator =
    ( name
    , function
      | [ Fixnum a; Fixnum b ] -> Fixnum (operator a b)
      | _ -> raise (Type_error_exn ("(" ^ name ^ " int int)")) )
  ;;
end

module Cmp = struct
  let generate name operator =
    ( name
    , function
      | [ Fixnum a; Fixnum b ] -> Boolean (operator a b)
      | _ -> raise (Type_error_exn ("(" ^ name ^ " int int)")) )
  ;;
end
