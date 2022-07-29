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
open Types.Object

let rec eval_expr expr env =
  let eval_apply fn_expr args =
    match fn_expr with
    | Primitive (_, f) -> f args
    | Closure (ns, e, clenv) ->
        eval_expr e (Environment.bind_list ns args clenv)
    | _ -> raise (Type_error_exn "(apply prim '(args)) or (prim args)")
  in
  let rec eval = function
    | Literal (Quote e) -> e
    | Literal l -> l
    | Var n -> Environment.lookup (n, env)
    | If (cond, if_true, _) when eval cond = Boolean true -> eval if_true
    | If (cond, _, if_false) when eval cond = Boolean false -> eval if_false
    | If _ -> raise (Type_error_exn "(if bool e1 e2)")
    | And (cond_x, cond_y) -> (
        match (eval cond_x, eval cond_y) with
        | Boolean x, Boolean y -> Boolean (x && y)
        | _ -> raise (Type_error_exn "(and bool bool)"))
    | Or (cond_x, cond_y) -> (
        match (eval cond_x, eval cond_y) with
        | Boolean v1, Boolean v2 -> Boolean (v1 || v2)
        | _ -> raise (Type_error_exn "(or bool bool)"))
    | Apply (fn, args) -> eval_apply (eval fn) (Object.pair_to_list (eval args))
    | Call (Var "env", []) -> Environment.env_to_val env
    | Call (fn, args) -> eval_apply (eval fn) (List.map eval args)
    | Lambda (args, body) -> Closure (args, body, env)
    | Defexpr _ -> raise This_can't_happen_exn
  in
  eval expr

let eval_def def env =
  match def with
  | Setq (name, expr) ->
      let v = eval_expr expr env in
      (v, Environment.bind (name, v, env))
  | Defun (n, ns, e) ->
      let formals, body, cl_env =
        match eval_expr (Lambda (ns, e)) env with
        | Closure (fs, bod, env) -> (fs, bod, env)
        | _ -> raise (Type_error_exn "Expecting closure.")
      in
      let loc = Environment.mk_loc () in
      let clo =
        Closure (formals, body, Environment.bind_loc (n, loc, cl_env))
      in
      let () = loc := Some clo in
      (clo, Environment.bind_loc (n, loc, env))
  | Expr e -> (eval_expr e env, env)

let eval ast env =
  match ast with
  | Defexpr def_expr -> eval_def def_expr env
  | expr -> (eval_expr expr env, env)
