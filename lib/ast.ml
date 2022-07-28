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

include Object

type t = Object.t
and value = lobject
and name = string

and expr =
  | Literal of value
  | Var of name
  | If of expr * expr * expr
  | And of expr * expr
  | Or of expr * expr
  | Apply of expr * expr
  | Call of expr * expr list
  | Defexpr of def

and def = Define of name * expr | Expr of expr

exception Parse_error_exn of string

let rec build_ast sexprr =
  match sexprr with
  | Primitive _ -> raise This_can't_happen_exn
  | Fixnum _ | Boolean _ | Quote _ | Nil -> Literal sexprr
  | Symbol s -> Var s
  | Pair _ when is_list sexprr -> (
      match pair_to_list sexprr with
      | [ Symbol "quote"; expr] -> Literal (Quote expr)
      | [ Symbol "if"; cond; if_true; if_false ] ->
          If (build_ast cond, build_ast if_true, build_ast if_false)
      | [ Symbol "and"; c1; c2 ] -> And (build_ast c1, build_ast c2)
      | [ Symbol "or"; c1; c2 ] -> Or (build_ast c1, build_ast c2)
      | [ Symbol "define"; Symbol name; expr ] ->
          Defexpr (Define (name, build_ast expr))
      | [ Symbol "apply"; fn_exprr; args ] when is_list args ->
          Apply (build_ast fn_exprr, build_ast args)
      | fn_exprr :: args -> Call (build_ast fn_exprr, List.map build_ast args)
      | [] -> raise (Parse_error_exn "poorly formed exprrression"))
  | Pair _ -> Literal sexprr

let rec string_expr = function
  | Literal e -> string_val e
  | Var n -> n
  | If (c, t, f) ->
      "(if " ^ string_expr c ^ " " ^ string_expr t ^ " " ^ string_expr f ^ ")"
  | And (c0, c1) -> "(and " ^ string_expr c0 ^ " " ^ string_expr c1 ^ ")"
  | Or (c0, c1) -> "(or " ^ string_expr c0 ^ " " ^ string_expr c1 ^ ")"
  | Apply (f, e) -> "(apply " ^ string_expr f ^ " " ^ string_expr e ^ ")"
  | Call (f, es) ->
      let string_es = String.concat " " (List.map string_expr es) in
      "(" ^ string_expr f ^ " " ^ string_es ^ ")"
  | Defexpr (Define (n, e)) -> "(val " ^ n ^ " " ^ string_expr e ^ ")"
  | Defexpr (Expr e) -> string_expr e

and string_val e =
  let rec string_list l =
    match l with
    | Pair (a, Nil) -> string_val a
    | Pair (a, b) -> string_val a ^ " " ^ string_list b
    | _ -> raise This_can't_happen_exn
  in
  let string_pair p =
    match p with
    | Pair (a, b) -> string_val a ^ " . " ^ string_val b
    | _ -> raise This_can't_happen_exn
  in
  match e with
  | Fixnum v -> string_of_int v
  | Boolean b -> if b then "#t" else "#f"
  | Symbol s -> s
  | Nil -> "nil"
  | Pair (_, _) ->
      "(" ^ (if is_list e then string_list e else string_pair e) ^ ")"
  | Primitive (name, _) -> "#<primitive:" ^ name ^ ">"
  | Quote expr -> "'" ^ string_val expr
