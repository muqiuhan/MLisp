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

open Mlisp_object
open Mlisp_error

let extend newenv oldenv =
  List.fold_right
    (fun (b, v) acc -> Object.bind_local (b, v, acc))
    newenv oldenv

let rec unzip l =
  match l with
  | [] -> ([], [])
  | (a, b) :: rst ->
    let flist, slist = unzip rst in
    (a :: flist, b :: slist)

let rec eval_expr expr env =
  let rec eval = function
    | Object.Literal (Object.Quote expr) -> expr
    | Object.Literal l -> l
    | Object.Var n -> Object.lookup (n, env)
    | Object.If (cond, if_true, _) when eval cond = Object.Boolean true ->
      eval if_true
    | Object.If (cond, _, if_false) when eval cond = Object.Boolean false ->
      eval if_false
    | Object.If _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(if bool e1 e2)"))
    | Object.And (cond_x, cond_y) -> (
      match (eval cond_x, eval cond_y) with
      | Object.Boolean x, Object.Boolean y -> Object.Boolean (x && y)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "(and bool bool)")))
    | Object.Or (cond_x, cond_y) -> (
      match (eval cond_x, eval cond_y) with
      | Object.Boolean x, Object.Boolean y -> Object.Boolean (x || y)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(or bool bool)"))
      )
    | Object.Apply (fn, args) ->
      eval_apply (eval fn) (Object.pair_to_list (eval args)) env
    | Object.Call (Var "env", []) -> Object.env_to_val env
    | Object.Call (fn, args) -> eval_apply (eval fn) (List.map eval args) env
    | Object.Lambda (name, args, body) -> Object.Closure (name, args, body, env)
    | Object.Let (Object.LET, bindings, body) ->
      let eval_binding (n, e) = (n, ref (Some (eval e))) in
      eval_expr body (extend (List.map eval_binding bindings) env)
    | Object.Let (Object.LETSTAR, bindings, body) ->
      let eval_binding acc (n, e) = Object.bind (n, eval_expr e acc, acc) in
      eval_expr body (List.fold_left eval_binding env bindings)
    | Object.Let (Object.LETREC, bindings, body) ->
      let names, values = unzip bindings in
      let env' =
        Object.bind_local_list names (List.map Object.make_local values) env
      in
      let updates =
        List.map (fun (n, e) -> (n, Some (eval_expr e env'))) bindings
      in
      let () = List.iter (fun (n, v) -> List.assoc n env' := v) updates in
      eval_expr body env'
    | Object.Defexpr _ -> failwith "This can't happen"
  in
  eval expr

and eval_apply fn_expr args env =
  match fn_expr with
  | Object.Primitive (_, fn) -> fn args
  | Object.Closure (fn_name, names, expr, clenv) ->
    (* Check if the closure exists *)
    Object.lookup (fn_name, env) |> ignore;
    eval_closure names expr args clenv env
  | fn_expr ->
    raise (Errors.Parse_error_exn (Apply_error (Object.string_object fn_expr)))

and eval_closure names expr args clenv env =
  eval_expr expr (extend (Object.bind_list names args clenv) env)

and eval_def def env =
  match def with
  | Object.Setq (name, expr) ->
    let v = eval_expr expr env in
    (v, Object.bind (name, v, env))
  | Object.Defun (name, args, body) ->
    let formals, body', cl_env =
      match eval_expr (Object.Lambda (name, args, body)) env with
      | Closure (_, fs, bod, env) -> (fs, bod, env)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "Expecting closure."))
    in
    let loc = Object.make_local () in
    let clo =
      Object.Closure
        (name, formals, body', Object.bind_local (name, loc, cl_env))
    in
    let () = loc := Some clo in
    (clo, Object.bind_local (name, loc, env))
  | Defrecord (name, fields) ->
    let constructor =
      Object.Defun
        ( name,
          fields,
          Object.Literal
            (Object.Record
               ( name,
                 List.map
                   (fun field -> (field, Object.lookup (field, env)))
                   fields )) )
    in
    eval_def constructor env
  | Expr e -> (eval_expr e env, env)

and eval ast env =
  match ast with
  | Object.Defexpr def_expr -> eval_def def_expr env
  | expr -> (eval_expr expr env, env)
