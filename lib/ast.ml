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

open Types.Object
open Types.Ast

let rec assert_unique = function
  | [] -> ()
  | x :: xs ->
    if List.mem x xs then raise (Parse_error_exn (Unique_error x)) else assert_unique xs
;;

let let_kinds = [ "let", LET; "let*", LETSTAR; "letrec", LETREC ]
let valid_let s = List.mem_assoc s let_kinds
let to_kind s = List.assoc s let_kinds

let rec build_ast sexpr =
  match sexpr with
  | Primitive _ | Closure _ -> raise This_can't_happen_exn
  | Fixnum _ | Boolean _ | Quote _ | String _ | Nil -> Literal sexpr
  | Symbol symbol -> Var symbol
  | Pair _ when Object.is_list sexpr ->
    (match Object.pair_to_list sexpr with
    | [ Symbol "if"; cond; if_true; if_false ] ->
      If (build_ast cond, build_ast if_true, build_ast if_false)
    | Symbol "cond" :: conditions -> cond_to_if conditions
    | [ Symbol "and"; cond_x; cond_y ] -> And (build_ast cond_x, build_ast cond_y)
    | [ Symbol "or"; cond_x; cond_y ] -> Or (build_ast cond_x, build_ast cond_y)
    | [ Symbol "quote"; expr ] -> Literal (Quote expr)
    | [ Symbol "setq"; Symbol name; expr ] -> Defexpr (Setq (name, build_ast expr))
    | [ Symbol "lambda"; args; body ] when Object.is_list args ->
      let names =
        List.map
          (function
            | Symbol s -> s
            | _ -> raise (Parse_error_exn (Type_error "(lambda (formals) body)")))
          (Object.pair_to_list args)
      in
      let () = assert_unique names in
      Lambda (names, build_ast body)
    | [ Symbol "apply"; fn_expr; args ] -> Apply (build_ast fn_expr, build_ast args)
    | [ Symbol "defun"; Symbol fn_name; args; body ] ->
      let names =
        List.map
          (function
            | Symbol s -> s
            | _ -> raise (Parse_error_exn (Type_error "(defun name (formals) body)")))
          (Object.pair_to_list args)
      in
      let () = assert_unique names in
      let lam = Lambda (names, build_ast body) in
      Defexpr (Setq (fn_name, Let (LETREC, [ fn_name, lam ], Var fn_name)))
    | [ Symbol s; bindings; expr ] when Object.is_list bindings && valid_let s ->
      let make_binding = function
        | Pair (Symbol n, Pair (expr, Nil)) -> n, build_ast expr
        | _ -> raise (Parse_error_exn (Type_error "(let bindings expr)"))
      in
      let bindings = List.map make_binding (Object.pair_to_list bindings) in
      let () = assert_unique (List.map fst bindings) in
      Let (to_kind s, bindings, build_ast expr)
    | fn_expr :: args -> Call (build_ast fn_expr, List.map build_ast args)
    | [] -> raise (Parse_error_exn Poorly_formed_expression))
  | Pair _ -> Literal sexpr

and cond_to_if = function
  | [] -> Literal (Symbol "error")
  | Pair (cond, Pair (res, Nil)) :: condpairs ->
    If (build_ast cond, build_ast res, cond_to_if condpairs)
  | _ -> raise (Parse_error_exn (Type_error "(cond conditions)"))
;;

let spacesep ns = String.concat " " ns

let rec string_expr =
  let spacesep_exp es = spacesep (List.map string_expr es) in
  let string_of_binding (n, e) = "(" ^ n ^ " " ^ string_expr e ^ ")" in
  function
  | Literal e -> string_object e
  | Var n -> n
  | If (c, t, f) ->
    "(if " ^ string_expr c ^ " " ^ string_expr t ^ " " ^ string_expr f ^ ")"
  | And (c0, c1) -> "(and " ^ string_expr c0 ^ " " ^ string_expr c1 ^ ")"
  | Or (c0, c1) -> "(or " ^ string_expr c0 ^ " " ^ string_expr c1 ^ ")"
  | Apply (f, e) -> "(apply " ^ string_expr f ^ " " ^ string_expr e ^ ")"
  | Call (f, es) ->
    if List.length es == 0
    then "(" ^ string_expr f ^ spacesep_exp es ^ ")"
    else "(" ^ string_expr f ^ " " ^ spacesep_exp es ^ ")"
  | Lambda (args, body) -> "(lambda (" ^ spacesep args ^ ") " ^ string_expr body ^ ")"
  | Defexpr (Setq (n, e)) -> "(setq " ^ n ^ " " ^ string_expr e ^ ")"
  | Defexpr (Defun (n, ns, e)) ->
    "(defun " ^ n ^ "(" ^ spacesep ns ^ ") " ^ string_expr e ^ ")"
  | Defexpr (Expr e) -> string_expr e
  | Let (kind, bs, e) ->
    let str =
      match kind with
      | LET -> "let"
      | LETSTAR -> "let*"
      | LETREC -> "letrec"
    in
    let bindings = spacesep (List.map string_of_binding bs) in
    "(" ^ str ^ " (" ^ bindings ^ ") " ^ string_expr e ^ ")"

and string_object e =
  let rec string_list l =
    match l with
    | Pair (a, Nil) -> string_object a
    | Pair (a, b) -> string_object a ^ " " ^ string_list b
    | _ -> raise This_can't_happen_exn
  in
  let string_pair p =
    match p with
    | Pair (a, b) -> string_object a ^ " . " ^ string_object b
    | _ -> raise This_can't_happen_exn
  in
  match e with
  | Fixnum v -> string_of_int v
  | Boolean b -> if b then "#t" else "#f"
  | String s -> "\"" ^ s ^ "\""
  | Symbol s -> s
  | Nil -> "nil"
  | Pair (_, _) -> "(" ^ (if Object.is_list e then string_list e else string_pair e) ^ ")"
  | Primitive (name, _) -> "#<primitive:" ^ name ^ ">"
  | Quote expr -> "'" ^ string_object expr
  | Closure (_, _, _) -> "#<closure>"
;;
