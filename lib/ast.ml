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
open Types.Ast

let rec build_ast sexpr =
  match sexpr with
  | Primitive _ | Closure _ -> raise This_can't_happen_exn
  | Fixnum _ | Boolean _ | Nil | Quote _ -> Literal sexpr
  | Symbol symbol -> Var symbol
  | Pair _ when Object.is_list sexpr -> (
      match Object.pair_to_list sexpr with
      | [ Symbol "if"; cond; if_true; if_false ] ->
          If (build_ast cond, build_ast if_true, build_ast if_false)
      | [ Symbol "and"; cond_x; cond_y ] ->
          And (build_ast cond_x, build_ast cond_y)
      | [ Symbol "or"; cond_x; cond_y ] ->
          Or (build_ast cond_x, build_ast cond_y)
      | [ Symbol "quote"; expr ] -> Literal (Quote expr)
      | [ Symbol "setq"; Symbol name; expr ] ->
          Defexpr (Setq (name, build_ast expr))
      | [ Symbol "lambda"; ns; e ] when Object.is_list ns ->
          let names =
            List.map
              (function
                | Symbol symbol -> symbol
                | _ -> raise (Type_error_exn "(lambda (formals) body)"))
              (Object.pair_to_list ns)
          in
          Lambda (names, build_ast e)
      | [ Symbol "defun"; Symbol name; args; expr ] ->
          let err () = raise (Type_error_exn "(defun name (formals) body)") in
          let names =
            List.map
              (function Symbol s -> s | _ -> err ())
              (Object.pair_to_list args)
          in
          Defexpr (Defun (name, names, build_ast expr))
      | [ Symbol "apply"; fn_expr; args ] ->
          Apply (build_ast fn_expr, build_ast args)
      | fn_expr :: args -> Call (build_ast fn_expr, List.map build_ast args)
      | [] -> raise (Parse_error_exn "poorly formed expression"))
  | Pair _ -> Literal sexpr

let spacesep ns = String.concat " " ns

let rec string_exp =
  let spacesep_exp es = spacesep (List.map string_exp es) in
  function
  | Literal e -> string_val e
  | Var n -> n
  | If (c, t, f) ->
      "(if " ^ string_exp c ^ " " ^ string_exp t ^ " " ^ string_exp f ^ ")"
  | And (c0, c1) -> "(and " ^ string_exp c0 ^ " " ^ string_exp c1 ^ ")"
  | Or (c0, c1) -> "(or " ^ string_exp c0 ^ " " ^ string_exp c1 ^ ")"
  | Apply (f, e) -> "(apply " ^ string_exp f ^ " " ^ string_exp e ^ ")"
  | Call (f, es) -> "(" ^ string_exp f ^ " " ^ spacesep_exp es ^ ")"
  | Lambda (_, _) -> "#<lambda>"
  | Defexpr (Setq (n, e)) -> "(val " ^ n ^ " " ^ string_exp e ^ ")"
  | Defexpr (Defun (n, ns, e)) ->
      "(defun " ^ n ^ "(" ^ spacesep ns ^ ") " ^ string_exp e ^ ")"
  | Defexpr (Expr e) -> string_exp e

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
      "(" ^ (if Object.is_list e then string_list e else string_pair e) ^ ")"
  | Primitive (name, _) -> "#<primitive:" ^ name ^ ">"
  | Quote expr -> "'" ^ string_val expr
  | Closure (_, _, _) -> "#<closure>"
