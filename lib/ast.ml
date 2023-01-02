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
      if List.mem x xs then raise (Parse_error_exn (Unique_error x))
      else assert_unique xs

let assert_unique_args args =
  let names =
    List.map
      (function
        | Symbol s -> s
        | _ ->
            raise (Parse_error_exn (Type_error "(defun name (formals) body)")))
      (Object.pair_to_list args)
  in
  let () = assert_unique names in
  names

let let_kinds = [ ("let", LET); ("let*", LETSTAR); ("letrec", LETREC) ]
let valid_let s = List.mem_assoc s let_kinds
let to_kind s = List.assoc s let_kinds

let rec build_ast sexpr =
  match sexpr with
  | Primitive _ | Closure _ -> raise This_can't_happen_exn
  | Fixnum _ | Boolean _ | Quote _ | String _ | Record _ | Nil ->
      literal_expr sexpr
  | Symbol s -> symbol_expr s
  | Pair _ when Object.is_list sexpr -> (
      match Object.pair_to_list sexpr with
      | [ Symbol "if"; cond; if_true; if_false ] ->
          if_expr cond if_true if_false
      | Symbol "cond" :: conditions -> cond_to_if conditions
      | [ Symbol "and"; cond_x; cond_y ] -> and_expr cond_x cond_y
      | [ Symbol "or"; cond_x; cond_y ] -> or_expr cond_x cond_y
      | [ Symbol "quote"; expr ] -> quote_expr expr
      | [ Symbol "setq"; Symbol name; expr ] -> setq_expr name expr
      | [ Symbol "record"; Symbol name; fields ] -> record_expr name fields
      | [ Symbol "lambda"; args; body ] when Object.is_list args ->
          lambda_expr args body
      | [ Symbol "apply"; fn_expr; args ] -> apply_expr fn_expr args
      | [ Symbol "defun"; Symbol fn_name; args; body ] ->
          defun_expr fn_name args body
      | [ Symbol s; bindings; expr ] when Object.is_list bindings && valid_let s
        ->
          let_expr s bindings expr
      | fn_expr :: args -> call_expr fn_expr args
      | [] -> raise (Parse_error_exn Poorly_formed_expression))
  | Pair _ -> Literal sexpr

and literal_expr sexpr = Literal sexpr
and symbol_expr s = Var s
and and_expr cond_x cond_y = And (build_ast cond_x, build_ast cond_y)
and or_expr cond_x cond_y = Or (build_ast cond_x, build_ast cond_y)
and quote_expr expr = Literal (Quote expr)
and setq_expr name expr = Defexpr (Setq (name, build_ast expr))

and if_expr cond if_true if_false =
  If (build_ast cond, build_ast if_true, build_ast if_false)

and record_expr name fields =
  Defexpr (Defrecord (name, assert_unique_args fields))

and lambda_expr args body = Lambda (assert_unique_args args, build_ast body)

and defun_expr fn_name args body =
  let lam = Lambda (assert_unique_args args, build_ast body) in
  Defexpr (Setq (fn_name, Let (LETREC, [ (fn_name, lam) ], Var fn_name)))

and apply_expr fn_expr args = Apply (build_ast fn_expr, build_ast args)

and let_expr s bindings expr =
  let make_binding = function
    | Pair (Symbol n, Pair (expr, Nil)) -> (n, build_ast expr)
    | _ -> raise (Parse_error_exn (Type_error "(let bindings expr)"))
  in
  let bindings = List.map make_binding (Object.pair_to_list bindings) in
  let () = assert_unique (List.map fst bindings) in
  Let (to_kind s, bindings, build_ast expr)

and call_expr fn_expr args = Call (build_ast fn_expr, List.map build_ast args)

and cond_to_if = function
  | [] -> Literal (Symbol "error")
  | Pair (cond, Pair (res, Nil)) :: condpairs ->
      If (build_ast cond, build_ast res, cond_to_if condpairs)
  | _ -> raise (Parse_error_exn (Type_error "(cond conditions)"))

let rec string_expr =
  let spacesep_exp es = Utils.spacesep (List.map string_expr es) in
  let string_of_binding (n, e) = "(" ^ n ^ " " ^ string_expr e ^ ")" in
  function
  | Literal e -> Object.string_object e
  | Var n -> n
  | If (c, t, f) ->
      "(if " ^ string_expr c ^ " " ^ string_expr t ^ " " ^ string_expr f ^ ")"
  | And (c0, c1) -> "(and " ^ string_expr c0 ^ " " ^ string_expr c1 ^ ")"
  | Or (c0, c1) -> "(or " ^ string_expr c0 ^ " " ^ string_expr c1 ^ ")"
  | Apply (f, e) -> "(apply " ^ string_expr f ^ " " ^ string_expr e ^ ")"
  | Call (f, es) ->
      if List.length es == 0 then "(" ^ string_expr f ^ spacesep_exp es ^ ")"
      else "(" ^ string_expr f ^ " " ^ spacesep_exp es ^ ")"
  | Lambda (args, body) ->
      "(lambda (" ^ Utils.spacesep args ^ ") " ^ string_expr body ^ ")"
  | Defexpr (Setq (n, e)) -> "(setq " ^ n ^ " " ^ string_expr e ^ ")"
  | Defexpr (Defun (n, ns, e)) ->
      "(defun " ^ n ^ "(" ^ Utils.spacesep ns ^ ") " ^ string_expr e ^ ")"
  | Defexpr (Expr e) -> string_expr e
  | Defexpr (Defrecord (name, field_list)) ->
      "(record " ^ name ^ Utils.spacesep field_list ^ ")"
  | Let (kind, bs, e) ->
      let str =
        match kind with LET -> "let" | LETSTAR -> "let*" | LETREC -> "letrec"
      in
      let bindings = Utils.spacesep (List.map string_of_binding bs) in
      "(" ^ str ^ " (" ^ bindings ^ ") " ^ string_expr e ^ ")"
  | Consexpr (Consrecord (name, fields)) ->
      "(" ^ name ^ " " ^ String.concat " " fields ^ ")"
