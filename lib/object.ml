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

type lobject =
  | Fixnum of int
  | Boolean of bool
  | Symbol of string
  | Nil
  | Pair of lobject * lobject
  | Primitive of string * (lobject list -> lobject)
  | Quote of value
and value = lobject

type t = lobject

exception This_can't_happen_exn
exception Type_error_exn of string

let rec is_list = function Nil -> true | Pair (_, b) -> is_list b | _ -> false

let rec print_sexpr sexpr =
  match sexpr with
  | Fixnum v -> print_int v
  | Boolean b -> print_string (if b then "#t" else "#f")
  | Symbol s -> print_string s
  | Nil -> print_string "nil"
  | Pair (_, _) ->
      print_string "(";
      if is_list sexpr then print_list sexpr else print_pair sexpr;
      print_string ")"
  | _ -> failwith "print_sexpr"

and print_list lst =
  match lst with
  | Pair (a, Nil) -> print_sexpr a
  | Pair (a, b) ->
      print_sexpr a;
      print_string " ";
      print_list b
  | _ -> raise This_can't_happen_exn

and print_pair pair =
  match pair with
  | Pair (a, b) ->
      print_sexpr a;
      print_string " . ";
      print_sexpr b
  | _ -> raise This_can't_happen_exn

let rec pair_to_list pair =
  match pair with
  | Nil -> []
  | Pair (a, b) -> a :: pair_to_list b
  | _ -> failwith "pair_to_list"
