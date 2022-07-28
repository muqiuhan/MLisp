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

exception Not_found_exn of string

let rec lookup (name, sexpr) =
  match sexpr with
  | Object.Nil -> raise (Not_found_exn name)
  | Object.Pair (Object.Pair (Object.Symbol name', value), rest) ->
      if name = name' then value else lookup (name, rest)
  | _ -> raise Object.This_can't_happen_exn

let bind (name, value, sexpr) =
  Object.Pair (Object.Pair (Object.Symbol name, value), sexpr)

let basis =
  let rec prim_list = function
    | [] -> Object.Nil
    | car :: cdr -> Object.Pair (car, prim_list cdr)
  in
  let prim_plus = function
    | [ Object.Fixnum a; Object.Fixnum b ] -> Object.Fixnum (a + b)
    | _ -> raise (Object.Type_error_exn "(+ int int)")
  in
  let prim_pair = function
    | [ a; b ] -> Object.Pair (a, b)
    | _ -> raise (Object.Type_error_exn "(pair a b)")
  in
  let newprim acc (name, func) = bind (name, Primitive (name, func), acc) in
  List.fold_left newprim Nil
    [
      ("list", prim_list);
      ("+", prim_plus);
      ("pair", prim_pair)
    ]
