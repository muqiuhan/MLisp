(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core

(** MLisp expression evaluator with optimized environment handling.

    This module implements the core evaluation engine for MLisp with
    performance optimizations including hash-based environments and
    selective closure variable capture.
*)

(** Extend an environment with a list of variable bindings.

    Creates a new child environment and populates it with the provided
    variable bindings. This function is optimized to work with the
    hash-table based environment system.

    @param newenv List of (name, value_ref) pairs to bind
    @param oldenv Parent environment to extend
    @return New extended environment
*)
let extend newenv oldenv =
  let new_env = Object.extend_env oldenv in
    List.iter newenv ~f:(fun (b, v) ->
      Object.bind_local (b, v, new_env) |> ignore);
    new_env
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
    | Object.If (cond, if_true, if_false) as expr -> begin
      match eval cond with
      | Object.Boolean true -> eval if_true
      | Object.Boolean false -> eval if_false
      | _ ->
        raise
          (Errors.Syntax_error_exn
             (Errors.Illegal_if_expression (Mlisp_ast.Ast.string_expr expr)))
    end
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
    (** Evaluate lambda expressions with optimized closure creation.

        Creates function closures with intelligent variable capture strategy:
        - If no free variables: use legacy full environment capture
        - If free variables exist: use optimized selective capture

        This optimization significantly reduces memory usage and improves
        performance for closures with many captured variables.

        @param name Function name (for debugging/named functions)
        @param args Parameter names
        @param body Function body expression
        @param env Environment where lambda is defined
        @return Closure object with optimized or legacy environment
    *)
    | Object.Lambda (name, args, body) ->
      let free_vars = Object.analyze_free_vars body (name :: args) in
        if List.is_empty free_vars then
          (* if no free variables, use the old full environment *)
          Object.Closure (name, args, body, Object.Legacy env)
        else (
          (* if there are free variables, use the optimized environment *)
          let closure_env = Object.create_closure_env free_vars env in
            Object.Closure (name, args, body, Object.Optimized closure_env)
        )
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
            match Object.lookup (n, env') with
            | exception Errors.Runtime_error_exn _ -> ()
            | _ -> Object.bind_local (n, ref v, env') |> ignore)
          updates
      in
        eval_expr body env'
    | Object.ModuleDef (name, exports, body_exprs) ->
      let module_obj, _ = eval_module name exports body_exprs env in
        module_obj
    | Object.Import import_spec ->
      let () = eval_import import_spec env in
        Object.Symbol "ok"
    | Object.Defexpr _ ->
      raise (Errors.Syntax_error_exn (Invalid_define_expression ""))
  in
    eval expr

(** Apply a function to arguments with optimized closure handling.

    Dispatches function application based on the function type:
    - Primitive functions: direct application
    - Closures: optimized environment handling
    - Other types: error reporting

    @param fn_expr Function to apply
    @param args Arguments to pass to the function
    @param env Current environment
    @return Result of function application
*)
and eval_apply fn_expr args env =
  match fn_expr with
  | Object.Primitive (_, fn) -> fn args
  | Object.Closure (fn_name, names, expr, closure_data) ->
    (* Check if the closure exists *)
    if String.equal fn_name "lambda" |> not then
      Object.lookup (fn_name, env) |> ignore;
    eval_closure names expr args closure_data env
  | fn_expr ->
    raise (Errors.Parse_error_exn (Apply_error (Object.string_object fn_expr)))

(** Execute closure body with optimized environment handling.

    Handles both legacy full environment capture and optimized
    selective variable capture, ensuring compatibility while
    providing performance benefits.

    @param names Parameter names to bind
    @param expr Closure body to execute
    @param args Arguments to bind to parameters
    @param closure_data Environment data (legacy or optimized)
    @param env Current call environment
    @return Result of closure execution
*)
and eval_closure names expr args closure_data env =
  match closure_data with
  | Object.Legacy cl_env ->
    (* use the old full environment *)
    let call_env = Object.bind_list names args cl_env in
      eval_expr expr call_env
  | Object.Optimized _cl_env ->
    (* use the optimized closure environment *)
    let call_env = Object.bind_list names args env in
      eval_expr expr call_env

and eval_def def env =
  match def with
  | Object.Setq (name, expr) ->
    let v = eval_expr expr env in
      v, Object.bind (name, v, env)
  | Object.Defun (name, args, body) ->
    let formals, body', closure_data =
      match eval_expr (Object.Lambda (name, args, body)) env with
      | Closure (_, fs, bod, data) -> fs, bod, data
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "Expecting closure."))
    in
    let loc = Object.make_local () in
    let clo =
      match closure_data with
      | Object.Legacy cl_env ->
        Object.Closure
          ( name
          , formals
          , body'
          , Object.Legacy (Object.bind_local (name, loc, cl_env)) )
      | Object.Optimized cl_env ->
        Object.Closure (name, formals, body', Object.Optimized cl_env)
    in
    let () = loc := Some clo in
      clo, Object.bind_local (name, loc, env)
  | Expr e -> eval_expr e env, env

(** Evaluate a module definition.

    Creates a new isolated environment for the module, evaluates all body
    expressions in that environment, and creates a module object with the
    specified exports. The module is automatically bound to its name in the
    parent environment.

    @param name Module name
    @param exports List of symbol names to export
    @param body_exprs List of expressions to evaluate in module scope
    @param env Parent environment (for imports and closures)
    @return Module object and updated environment with module bound *)
and eval_module name exports body_exprs env =
  let module_env = Object.extend_env env in
  (* Pre-bind the module to itself for recursive references *)
  let module_obj_ref = ref None in
  let temp_module_obj = Object.Module { name; env = module_env; exports = [] } in
  let () = module_obj_ref := Some temp_module_obj in
  let () = Object.bind (name, temp_module_obj, module_env) |> ignore in
  let () =
    List.iter body_exprs ~f:(fun expr ->
      match expr with
      | Object.Defexpr def_expr ->
        let _, updated_env = eval_def def_expr module_env in
          ignore updated_env
      | _ ->
        let _, updated_env = eval expr module_env in
          ignore updated_env)
  in
  (* Verify all exports exist in module environment *)
  let () =
    List.iter exports ~f:(fun export_name ->
      try
        Object.lookup (export_name, module_env) |> ignore
      with
      | Errors.Runtime_error_exn _ ->
        raise
          (Errors.Runtime_error_exn
             (Errors.Export_not_found (name, export_name))))
  in
  (* Create final module object with correct exports *)
  let final_module_obj = Object.Module { name; env = module_env; exports } in
  (* Update the module reference in module_env *)
  let () = Object.bind (name, final_module_obj, module_env) |> ignore in
    final_module_obj, Object.bind (name, final_module_obj, env)

(** Evaluate an import expression.

    Imports symbols from a module into the current environment. Supports
    three import modes:
    - ImportAll: import all exported symbols
    - ImportSelective: import only specified symbols
    - ImportAs: import all symbols with a namespace prefix

    @param import_spec Import specification
    @param env Current environment
    @return Unit (imports modify environment in place)
    @raise Errors.Runtime_error_exn if module not found or export not found *)
and eval_import import_spec env =
  let module_obj, import_name =
    match import_spec with
    | Object.ImportAll module_name ->
      let mod_obj = Object.lookup (module_name, env) in
        (match mod_obj with
         | Object.Module _ -> mod_obj, module_name
         | _ ->
           raise
             (Errors.Runtime_error_exn
                (Errors.Not_a_module module_name)))
    | Object.ImportSelective (module_name, _) ->
      let mod_obj = Object.lookup (module_name, env) in
        (match mod_obj with
         | Object.Module _ -> mod_obj, module_name
         | _ ->
           raise
             (Errors.Runtime_error_exn
                (Errors.Not_a_module module_name)))
    | Object.ImportAs (module_name, _) ->
      let mod_obj = Object.lookup (module_name, env) in
        (match mod_obj with
         | Object.Module _ -> mod_obj, module_name
         | _ ->
           raise
             (Errors.Runtime_error_exn
                (Errors.Not_a_module module_name)))
  in
    match module_obj, import_spec with
    | Object.Module { name = _; env = module_env; exports }, Object.ImportAll _ ->
      (* Import all exported symbols *)
      List.iter exports ~f:(fun export_name ->
        let value = Object.lookup (export_name, module_env) in
          Object.bind (export_name, value, env) |> ignore)
    | Object.Module { name = mod_name; env = module_env; exports }, Object.ImportSelective (_, import_names) ->
      (* Import only specified symbols *)
      List.iter import_names ~f:(fun import_name ->
        if List.mem exports import_name ~equal:String.equal then (
          let value = Object.lookup (import_name, module_env) in
            Object.bind (import_name, value, env) |> ignore
        ) else
          raise
            (Errors.Runtime_error_exn
               (Errors.Export_not_found (mod_name, import_name))))
    | Object.Module { name = _; env = module_env; exports }, Object.ImportAs (_, alias) ->
      (* Import all with namespace prefix *)
      List.iter exports ~f:(fun export_name ->
        let prefixed_name = [%string "%{alias}.%{export_name}"] in
        let value = Object.lookup (export_name, module_env) in
          Object.bind (prefixed_name, value, env) |> ignore)
    | _ ->
      raise (Errors.Runtime_error_exn (Errors.Not_a_module import_name))

(** Evaluate a module definition at the top level.

    Handles module definitions that appear at the top level of a program.
    Modules are bound to their names in the environment.

    @param name Module name
    @param exports List of exported symbol names
    @param body_exprs List of body expressions
    @param env Current environment
    @return Module object and updated environment *)
and eval_module_def name exports body_exprs env =
  eval_module name exports body_exprs env

and eval ast env =
  match ast with
  | Object.Defexpr def_expr -> eval_def def_expr env
  | Object.ModuleDef (name, exports, body_exprs) ->
    let _, updated_env = eval_module_def name exports body_exprs env in
      Object.Symbol "ok", updated_env
  | expr -> eval_expr expr env, env
;;
