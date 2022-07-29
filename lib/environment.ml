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

open Types

exception Not_found_exn of string
exception Unspecified_value_exn of string

let rec lookup = function
  | n, [] -> raise (Not_found_exn n)
  | n, (n', v) :: _ when n = n' -> (
      match !v with Some v' -> v' | None -> raise (Unspecified_value_exn n))
  | n, (_, _) :: bs -> lookup (n, bs)

let bind (name, value, sexpr) = (name, ref (Some value)) :: sexpr
let mk_loc () = ref None
let bind_loc (n, vor, e) = (n, vor) :: e

let bind_list ns vs env =
  List.fold_left2 (fun acc n v -> bind (n, v, acc)) env ns vs

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
  let newprim acc (name, func) =
    bind (name, Object.Primitive (name, func), acc)
  in
  List.fold_left newprim []
    [ ("list", prim_list); ("+", prim_plus); ("pair", prim_pair) ]

let rec env_to_val =
  let b_to_val (n, vor) =
    Object.Pair
      (Symbol n, match !vor with None -> Symbol "unspecified" | Some v -> v)
  in
  function
  | [] -> Object.Nil | b :: bs -> Object.Pair (b_to_val b, env_to_val bs)
