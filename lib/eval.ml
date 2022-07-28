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

include Ast

let rec eval_sexpr sexpr env =
  let eval_if cond if_true if_false =
    let condval, _ = eval_sexpr cond env in
    match condval with
    | Boolean true -> if_true
    | Boolean false -> if_false
    | _ -> raise (Type_error_exn "(if bool e1 e2)")
  in
  match sexpr with
  | Fixnum v -> (Fixnum v, env)
  | Boolean v -> (Boolean v, env)
  | Symbol name -> (Environment.lookup (name, env), env)
  | Nil -> (Nil, env)
  | Pair (_, _) when is_list sexpr -> (
      match pair_to_list sexpr with
      | [ Symbol "if"; cond; iftrue; iffalse ] ->
          let if_val, _ = eval_sexpr (eval_if cond iftrue iffalse) env in
          (if_val, env)
      | [ Symbol "env" ] -> (env, env)
      | [ Symbol "pair"; car; cdr ] -> (Pair (car, cdr), env)
      | [ Symbol "define"; Symbol name; expr ] ->
          let expr_define, _ = eval_sexpr expr env in
          let env' = Environment.bind (name, expr_define, env) in
          (expr_define, env')
      | Symbol fn :: args -> (
          match eval_sexpr (Symbol fn) env with
          | Primitive (_, f), _ -> (f args, env)
          | _ -> raise (Type_error_exn "(apply func args)"))
      | _ -> (sexpr, env))
  | _ -> (sexpr, env)

let eval_expr expr env =
  let eval_apply fn args =
    match fn with
    | Primitive (_, fn) -> fn args
    | _ -> raise (Type_error_exn "(apply prim '(args)) or (prim args")
  in
  let rec eval_ast = function
    | Literal Quote expr -> expr
    | Literal l -> l
    | Var name -> Environment.lookup (name, env)
    | If (cond, if_true, _) when eval_ast cond = Boolean true ->
        eval_ast if_true
    | If (cond, _, if_false) when eval_ast cond = Boolean false ->
        eval_ast if_false
    | If _ -> raise (Type_error_exn "(if bool e1 e2)")
    | And (cond_x, cond_y) -> (
        match (eval_ast cond_x, eval_ast cond_y) with
        | Boolean x, Boolean y -> Boolean (x && y)
        | _ -> raise (Type_error_exn "(or bool bool)"))
    | Or (cond_x, cond_y) -> (
        match (eval_ast cond_x, eval_ast cond_y) with
        | Boolean x, Boolean y -> Boolean (x || y)
        | _ -> raise (Type_error_exn "(or bool bool)"))
    | Apply (fn, args) ->
        eval_apply (eval_ast fn) (pair_to_list (eval_ast args))
    | Call (Var "env", []) -> env
    | Call (fn, args) -> eval_apply (eval_ast fn) (List.map eval_ast args)
    | Defexpr _ -> raise This_can't_happen_exn
  in
  eval_ast expr

let eval_def def_expr env =
  match def_expr with
  | Define (name, exprr) ->
      let value = eval_expr exprr env in
      (value, Environment.bind (name, value, env))
  | Expr expr -> (eval_expr expr env, env)

let eval ast env =
  match ast with
  | Defexpr def_expr -> eval_def def_expr env
  | expr -> (eval_expr expr env, env)
