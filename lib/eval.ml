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

include Ast
open Types.Object
open Types.Ast
open Types.Eval

let extend newenv oldenv =
  List.fold_right (fun (b, v) acc -> Environment.bind_local (b, v, acc)) newenv oldenv
;;

let rec unzip l =
  match l with
  | [] -> [], []
  | (a, b) :: rst ->
    let flist, slist = unzip rst in
    a :: flist, b :: slist
;;

let rec eval_expr expr env =
  let rec eval = function
    | Literal (Quote expr) -> expr
    | Literal l -> l
    | Var n -> Environment.lookup (n, env)
    | If (cond, if_true, _) when eval cond = Boolean true -> eval if_true
    | If (cond, _, if_false) when eval cond = Boolean false -> eval if_false
    | If _ -> raise (Type_error_exn "(if bool e1 e2)")
    | And (cond_x, cond_y) ->
      (match eval cond_x, eval cond_y with
      | Boolean x, Boolean y -> Boolean (x && y)
      | _ -> raise (Type_error_exn "(and bool bool)"))
    | Or (cond_x, cond_y) ->
      (match eval cond_x, eval cond_y with
      | Boolean x, Boolean y -> Boolean (x || y)
      | _ -> raise (Type_error_exn "(or bool bool)"))
    | Apply (fn, args) -> eval_apply (eval fn) (Object.pair_to_list (eval args)) env
    | Call (Var "env", []) -> Environment.env_to_val env
    | Call (fn, args) -> eval_apply (eval fn) (List.map eval args) env
    | Lambda (args, body) -> Closure (args, body, env)
    | Let (LET, bindings, body) ->
      let eval_binding (n, e) = n, ref (Some (eval e)) in
      eval_expr body (extend (List.map eval_binding bindings) env)
    | Let (LETSTAR, bindings, body) ->
      let eval_binding acc (n, e) = Environment.bind (n, eval_expr e acc, acc) in
      eval_expr body (List.fold_left eval_binding env bindings)
    | Let (LETREC, bindings, body) ->
      let names, values = unzip bindings in
      let env' =
        Environment.bind_local_list names (List.map Environment.make_local values) env
      in
      let updates = List.map (fun (n, e) -> n, Some (eval_expr e env')) bindings in
      let () = List.iter (fun (n, v) -> List.assoc n env' := v) updates in
      eval_expr body env'
    | Defexpr _ -> raise This_can't_happen_exn
  in
  try eval expr with
  | e -> raise (Eval_error_exn ("Error: " ^ (Printexc.to_string e) ^ " in expression : " ^ string_expr expr ))

and eval_apply fn_expr args _env =
  match fn_expr with
  | Primitive (_, fn) -> fn args;
  | Closure (names, expr, clenv) -> eval_closure names expr args clenv
  | _ -> raise (Type_error_exn "(apply prim '(args)) or (prim args)")

and eval_closure names expr args clenv =
  eval_expr expr (Environment.bind_list names args clenv)
;;

let eval_def def env =
  match def with
  | Setq (name, expr) ->
    let v = eval_expr expr env in
    v, Environment.bind (name, v, env)
  | Defun (name, args, body) ->
    let formals, body', cl_env =
      match eval_expr (Lambda (args, body)) env with
      | Closure (fs, bod, env) -> fs, bod, env
      | _ -> raise (Type_error_exn "Expecting closure.")
    in
    let loc = Environment.make_local () in
    let clo = Closure (formals, body', Environment.bind_local (name, loc, cl_env)) in
    let () = loc := Some clo in
    clo, Environment.bind_local (name, loc, env)
  | Expr e -> eval_expr e env, env
;;

let eval ast env =
  match ast with
  | Defexpr def_expr -> eval_def def_expr env
  | expr -> eval_expr expr env, env
;;
