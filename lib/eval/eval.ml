(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core

let extend newenv oldenv =
  newenv
  |> List.fold_right
       ~f:(fun (b, v) acc -> Object.bind_local (b, v, acc))
       ~init:oldenv
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
    | Object.Literal (Object.Quote expr) -> expr
    | Object.Literal l -> l
    | Object.Var n -> Object.lookup (n, env)
    | Object.If (cond, if_true, _)
      when phys_equal (eval cond) (Object.Boolean true) -> eval if_true
    | Object.If (cond, _, if_false)
      when phys_equal (eval cond) (Object.Boolean false) -> eval if_false
    | Object.If _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(? bool e1 e2)"))
    | Object.And (cond_x, cond_y) -> begin
      match eval cond_x, eval cond_y with
      | Object.Boolean x, Object.Boolean y -> Object.Boolean (x && y)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(&& bool bool)"))
    end
    | Object.Or (cond_x, cond_y) -> begin
      match eval cond_x, eval cond_y with
      | Object.Boolean x, Object.Boolean y -> Object.Boolean (x || y)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(|| bool bool)"))
    end
    | Object.Apply (fn, args) ->
      eval_apply (eval fn) (Object.pair_to_list (eval args)) env
    | Object.Call (Var "env", []) -> Object.env_to_val env
    | Object.Call (fn, args) -> eval_apply (eval fn) (List.map ~f:eval args) env
    | Object.Lambda (name, args, body) -> Object.Closure (name, args, body, env)
    | Object.Let (Object.LET, bindings, body) ->
      let eval_binding (n, e) = n, ref (Some (eval e)) in
        eval_expr body (extend (List.map ~f:eval_binding bindings) env)
    | Object.Let (Object.LETSTAR, bindings, body) ->
      let eval_binding acc (n, e) = Object.bind (n, eval_expr e acc, acc) in
        eval_expr body (List.fold_left ~f:eval_binding ~init:env bindings)
    | Object.Let (Object.LETREC, bindings, body) ->
      let names, values = unzip bindings in
      let env' =
        Object.bind_local_list names (List.map ~f:Object.make_local values) env
      in
      let updates =
        List.map ~f:(fun (n, e) -> n, Some (eval_expr e env')) bindings
      in
      let () =
        List.iter
          ~f:(fun (n, v) ->
            List.Assoc.find_exn env' ~equal:(fun n n' -> String.(n' = n)) n := v)
          updates
      in
        eval_expr body env'
    | Object.Defexpr _ ->
      raise (Errors.Syntax_error_exn (Invalid_define_expression ""))
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
      v, Object.bind (name, v, env)
  | Object.Defun (name, args, body) ->
    let formals, body', cl_env =
      match eval_expr (Object.Lambda (name, args, body)) env with
      | Closure (_, fs, bod, env) -> fs, bod, env
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "Expecting closure."))
    in
    let loc = Object.make_local () in
    let clo =
      Object.Closure
        (name, formals, body', Object.bind_local (name, loc, cl_env))
    in
    let () = loc := Some clo in
      clo, Object.bind_local (name, loc, env)
  | Expr e -> eval_expr e env, env

and eval ast env =
  match ast with
  | Object.Defexpr def_expr -> eval_def def_expr env
  | expr -> eval_expr expr env, env
;;
