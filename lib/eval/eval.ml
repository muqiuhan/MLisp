(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Mlisp_ast
open Mlisp_lexer
open Mlisp_macro
open Mlisp_utils
open Module_cache
open Core

(** Global reference to current execution stream for error/warning context *)
let current_stream : char Stream_wrapper.t option ref = ref None

(** Set the current stream context for error/warning reporting *)
let set_stream stream = current_stream := Some stream

(** Clear the current stream context *)
let clear_stream () = current_stream := None

(** MLisp expression evaluator with optimized environment handling.

    This module implements the core evaluation engine for MLisp with
    performance optimizations including hash-based environments and
    selective closure variable capture.
*)

(** Quasiquote expansion module.

    Implements the core quasiquote expansion algorithm that handles
    nested quasiquotes, unquotes, and unquote-splicing forms. The
    expansion depth is tracked to handle nested quasiquote correctly.
*)
module Quasiquote = struct
  (** Depth counter for tracking nested quasiquote levels *)
  let depth = ref 0

  (** Expand a quasiquote expression to its final S-expression form.

      The expansion algorithm:
      - At depth 1: unquote expressions are evaluated
      - At depth > 1: unquote expressions are preserved (nested quasiquote)
      - unquote-splicing: evaluates to a list and splices it into the result

      @param sexpr The S-expression to expand
      @param env Current environment for evaluation
      @param eval_fn Evaluation function for evaluating unquote expressions
      @return Expanded S-expression
  *)
  let rec expand sexpr env ~eval_fn =
    match sexpr with
    | Object.Unquote expr ->
      (* Unquote: evaluate at depth 1, preserve at deeper depths *)
      if !depth = 1 then
        eval_fn expr env
      else
        (* Keep the unquote wrapper for nested quasiquote *)
        Object.Unquote (expand expr env ~eval_fn)
    | Object.UnquoteSplicing expr ->
      (* Unquote-splicing: evaluate at depth 1 and splice *)
      if !depth = 1 then (
        match eval_fn expr env with
        | (Object.Pair _ | Object.Nil) as result ->
          result
        | _other ->
          raise
            (Errors.Runtime_error_exn
               (Errors.Not_found "unquote-splicing requires a list, got non-list value"))
      ) else
        (* Keep the unquote-splicing wrapper for nested quasiquote *)
        Object.UnquoteSplicing (expand expr env ~eval_fn)
    | Object.Quasiquote expr ->
      (* Nested quasiquote: increase depth and expand *)
      incr depth;
      let result = expand expr env ~eval_fn in
        decr depth;
        Object.Quasiquote result
    | Object.Pair (car, cdr) ->
      (* Recursively expand pairs, handling unquote-splicing *)
      (* First check if car is unquote-splicing at current depth *)
      begin match car with
      | Object.UnquoteSplicing splice_expr ->
        (* At depth 1, evaluate and splice; at depth >1, keep nested *)
        if !depth = 1 then (
          let splice_list = eval_fn splice_expr env in
          let expanded_cdr = expand cdr env ~eval_fn in
            (* Splice the list into the cdr *)
            Object.append_lists splice_list expanded_cdr
        ) else (
          (* Nested: keep the unquote-splicing wrapper *)
          let expanded_car = expand car env ~eval_fn in
          let expanded_cdr = expand cdr env ~eval_fn in
            Object.Pair (expanded_car, expanded_cdr)
        )
      | _ ->
        (* Normal pair: expand both car and cdr *)
        let expanded_car = expand car env ~eval_fn in
        let expanded_cdr = expand cdr env ~eval_fn in
          Object.Pair (expanded_car, expanded_cdr)
      end
    | _ ->
      (* Literals pass through unchanged *)
      sexpr

  (** Helper function to append two lists represented as pairs *)
  and append_lists list1 list2 =
    match list1 with
    | Object.Nil ->
      list2
    | Object.Pair (car, cdr) ->
      Object.Pair (car, append_lists cdr list2)
    | _ ->
      (* list1 is not a proper list, just cons *)
      Object.Pair (list1, list2)
  ;;
end

(** Expand a quasiquote S-expression to its final form.
    This is the public entry point for quasiquote expansion. *)
let expand_quasiquote sexpr env ~eval_fn =
  (* Reset depth to 0 and increment to 1 for the outermost quasiquote *)
  Quasiquote.depth := 1;
  try Quasiquote.expand sexpr env ~eval_fn with
  | e ->
    Quasiquote.depth := 0;
    raise e
;;

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
    List.iter newenv ~f:(fun (b, v) -> Object.bind_local (b, v, new_env) |> ignore);
    new_env
;;

let rec unzip l =
  match l with
  | [] ->
    [], []
  | (a, b) :: rst ->
    let flist, slist = unzip rst in
      a :: flist, b :: slist
;;

(** Evaluate a value in the context of quasiquote expansion.
    This function handles the fact that unquote contains Object.value
    rather than Object.expr. For symbols, we look them up in the environment.
    For other values, we return them as-is.
*)
let eval_value env value =
  match value with
  | Object.Symbol name ->
    (* Variable reference - look up in environment *)
    Object.lookup (name, env)
  | _ ->
    (* Literals pass through *)
    value
;;

let rec eval_expr expr env =
  (* Expand macros before evaluation *)
  let expanded_expr = Macro.expand expr env ~eval_fn:eval_expr in
  let rec eval expr =
    match expr with
    | Object.Literal (Object.Quote expr) ->
      expr
    | Object.Literal (Object.Quasiquote expr) ->
      (* Expand quasiquote: unquote expressions are evaluated to lobject values *)
      (* The eval_fn for quasiquote needs to handle Object.value -> Object.value *)
      expand_quasiquote expr env ~eval_fn:(fun value _env -> eval_value env value)
    | Object.Literal (Object.Unquote _) ->
      (* Unquote outside quasiquote is an error *)
      raise
        (Errors.Runtime_error_exn
           (Errors.Not_found "unquote appears outside of quasiquote"))
    | Object.Literal (Object.UnquoteSplicing _) ->
      (* Unquote-splicing outside quasiquote is an error *)
      raise
        (Errors.Runtime_error_exn
           (Errors.Not_found "unquote-splicing appears outside of quasiquote"))
    | Object.Literal l ->
      l
    | Object.Var n ->
      Object.lookup (n, env)
    | Object.If (cond, if_true, if_false) as expr -> begin
      match eval cond with
      | Object.Boolean true ->
        eval if_true
      | Object.Boolean false ->
        eval if_false
      | _ ->
        raise
          (Errors.Syntax_error_exn
             (Errors.Illegal_if_expression (Mlisp_ast.Ast.string_expr expr)))
    end
    | Object.And (cond_x, cond_y) -> begin
      match eval cond_x, eval cond_y with
      | Object.Boolean x, Object.Boolean y ->
        Object.Boolean (x && y)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "(&& bool bool)"))
    end
    | Object.Or (cond_x, cond_y) -> begin
      match eval cond_x, eval cond_y with
      | Object.Boolean x, Object.Boolean y ->
        Object.Boolean (x || y)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "(|| bool bool)"))
    end
    | Object.Apply (fn, args) ->
      eval_apply (eval fn) (Object.pair_to_list (eval args)) env
    | Object.Call (Var "env", []) ->
      Object.env_to_val env
    | Object.Call (Var "macroexpand-1", [ Object.Literal (Object.Quote sexpr) ]) ->
      (* Single-step macro expansion *)
      let ast = Ast.build_ast sexpr in
      let expanded = Macro.expand_1 ast env ~eval_fn:eval_expr in
        (* Return quoted expanded form *)
        Object.Quote (Macro.expr_to_sexpr expanded)
    | Object.Call (Var "macroexpand", [ Object.Literal (Object.Quote sexpr) ]) ->
      (* Full macro expansion *)
      let ast = Ast.build_ast sexpr in
      let expanded = Macro.expand ast env ~eval_fn:eval_expr in
        (* Return quoted expanded form *)
        Object.Quote (Macro.expr_to_sexpr expanded)
    | Object.Call (fn, args) ->
      eval_apply (eval fn) (List.map ~f:eval args) env
    (*  Evaluate lambda expressions with optimized closure creation.

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
    | Object.Let (Object.LET, bindings, body) -> (
      let eval_binding (n, e) = n, ref (Some (eval e)) in
      let let_env = extend (List.map ~f:eval_binding bindings) env in
        (* Special handling for nested Let with Defexpr: when body is a nested Let
           with Defexpr binding, evaluate the define expression in let_env to
           access outer let bindings. This handles cases like:
           (let ((y 10)) (define z (+ y 1)) z)
        *)
        match body with
        | Object.Let (Object.LET, inner_bindings, inner_body) -> (
          (* Handle nested Let: evaluate bindings in let_env context so they can access outer let bindings.
              Special case: if binding is Defexpr, evaluate its expression in let_env to access outer bindings.
              Also handle the special case from build_ast where define is wrapped in a temp let. *)
          match inner_bindings with
          | [ ("temp", Object.Defexpr (Object.Setq (name, expr))) ] ->
            (* Handle let body with define (from build_ast sequence): evaluate define expression in let_env *)
            let v = eval_expr expr let_env in
            let _ = Object.bind (name, v, let_env) in
              eval_expr inner_body let_env
          | _ ->
            let eval_inner_binding (n, e) =
              match e with
              | Object.Defexpr (Object.Setq (name, expr)) ->
                (* Evaluate define expression in let_env to access outer let bindings *)
                let v = eval_expr expr let_env in
                (* Bind the defined variable in let_env for the rest of the body *)
                let _ = Object.bind (name, v, let_env) in
                  n, ref (Some v)
              | _ ->
                n, ref (Some (eval_expr e let_env))
            in
            let inner_env =
              extend (List.map ~f:eval_inner_binding inner_bindings) let_env
            in
              eval_expr inner_body inner_env)
        | _ ->
          (* Normal let body evaluation *)
          eval_expr body let_env)
    | Object.Let (Object.LETSTAR, bindings, body) ->
      let eval_binding acc (n, e) = Object.bind (n, eval_expr e acc, acc) in
        eval_expr body (List.fold_left ~f:eval_binding ~init:env bindings)
    | Object.Let (Object.LETREC, bindings, body) ->
      let names, values = unzip bindings in
      let env' =
        Object.bind_local_list names (List.map ~f:Object.make_local values) env
      in
      let () =
        List.iter
          ~f:(fun (n, e) ->
            let v = eval_expr e env' in
              match Hashtbl.find env'.bindings n with
              | Some value_ref ->
                value_ref := Some v
              | None ->
                (* Should not happen, but handle gracefully *)
                Object.bind_local (n, ref (Some v), env') |> ignore)
          bindings
      in
        eval_expr body env'
    | Object.ModuleDef (name, exports, body_exprs) ->
      let module_obj, _ = eval_module name exports body_exprs env in
        module_obj
    | Object.Import import_spec ->
      (* Import now returns the module object *)
      eval_import import_spec env
    | Object.LoadModule module_name_expr ->
      (* Load module from file *)
      eval_load_module module_name_expr env
    | Object.Defexpr def_expr ->
      (* Defexpr can appear in expression context (e.g., lambda body) *)
      let value, _ = eval_def def_expr env in
        value
    | Object.MacroDef (_name, _params, _body) ->
      (* MacroDef should not appear in evaluation context - it should be Defexpr *)
      (* This is a programming error, but handle gracefully *)
      raise (Errors.Parse_error_exn (Errors.Type_error "MacroDef in evaluation context"))
  in
    eval expanded_expr

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
  | Object.Primitive (_, fn) ->
    fn args
  | Object.Closure (fn_name, names, expr, closure_data) ->
    (* Check if the closure exists *)
    if String.equal fn_name "lambda" |> not then Object.lookup (fn_name, env) |> ignore;
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
  | Object.Optimized cl_env ->
    (* use the optimized closure environment *)
    (* Get the parent environment from the closure *)
    let parent_env =
      match cl_env.parent_env with
      | Some p ->
        p
      | None ->
        env (* fallback to call environment if no parent *)
    in
    (* Create a new environment for the call, extending the parent *)
    let call_env = Object.extend_env parent_env in
      (* Bind captured variables to the call environment *)
      List.iter cl_env.captured_vars ~f:(fun (var_name, value_ref) ->
        Object.bind_local (var_name, value_ref, call_env) |> ignore);
      (* Bind parameters to their arguments *)
      let call_env_with_args = Object.bind_list names args call_env in
        eval_expr expr call_env_with_args

and eval_def def env =
  match def with
  | Object.Setq (name, expr) -> (
    let v = eval_expr expr env in
      (* Try to update existing binding first, otherwise create new one *)
      match Hashtbl.find env.bindings name with
      | Some value_ref ->
        value_ref := Some v;
        v, env
      | None ->
        v, Object.bind (name, v, env))
  | Object.Defun (name, args, body) ->
    let formals, body', closure_data =
      match eval_expr (Object.Lambda (name, args, body)) env with
      | Closure (_, fs, bod, data) ->
        fs, bod, data
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "Expecting closure."))
    in
    let loc = Object.make_local () in
    let clo =
      match closure_data with
      | Object.Legacy cl_env ->
        Object.Closure
          (name, formals, body', Object.Legacy (Object.bind_local (name, loc, cl_env)))
      | Object.Optimized cl_env ->
        Object.Closure (name, formals, body', Object.Optimized cl_env)
    in
    let () = loc := Some clo in
      clo, Object.bind_local (name, loc, env)
  | Object.Defmacro (name, params, body) ->
    (* Create a macro object with the current environment captured *)
    let macro_obj = Object.Macro (name, params, body, env) in
      macro_obj, Object.bind (name, macro_obj, env)
  | Expr e ->
    eval_expr e env, env

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
      | Object.Let (Object.LET, bindings, body) -> (
        (* Special handling for Let in module body: if body is a Defexpr,
           bind the variable in module_env instead of let_env *)
        match body with
        | Object.Defexpr (Object.Setq (name, expr_expr)) ->
          (* Evaluate bindings in module_env *)
          let eval_binding (n, e) = n, ref (Some (eval_expr e module_env)) in
          let let_env = Object.extend_env module_env in
          let () =
            List.iter (List.map ~f:eval_binding bindings) ~f:(fun (n, v_ref) ->
              Object.bind_local (n, v_ref, let_env) |> ignore)
          in
          (* Evaluate expr in let_env to access let bindings *)
          let v = eval_expr expr_expr let_env in
          (* But bind in module_env for export *)
          let _ = Object.bind (name, v, module_env) in
            ()
        | _ ->
          (* Normal let evaluation *)
          let _ = eval_expr expr module_env in
            ())
      | Object.Let _
      | Object.If _
      | Object.And _
      | Object.Or _ ->
        (* These expressions can contain definitions in their bodies, evaluate them *)
        let _ = eval_expr expr module_env in
          ()
      | Object.ModuleDef _
      | Object.Import _ ->
        (* Module and import are allowed in module body *)
        let _ = eval_expr expr module_env in
          ()
      | _ ->
        (* Non-definition expression in module body - issue warning *)
        let expr_str = Ast.string_expr expr in
        let warning_msg =
          [%string
            "Expression result will be discarded. Module bodies should contain only \
             definitions (define, defun, module, import)."]
        in
        (* Find the position of the expression in source code *)
        let find_expr_position source_lines expr_str =
          (* Normalize strings for comparison (remove whitespace and convert to lowercase) *)
          let normalize s =
            String.filter s ~f:(fun c -> not (Char.is_whitespace c)) |> String.lowercase
          in
          let normalized_expr = normalize expr_str in
          (* Search for the expression across all lines *)
          let rec search_lines lines line_num =
            match lines with
            | [] ->
              None
            | line :: rest ->
              let normalized_line = normalize line in
                (* Check if the line contains the expression *)
                if String.is_substring normalized_line ~substring:normalized_expr then (
                  (* Find the column position of the expression in the line *)
                  (* Look for the opening parenthesis of the expression *)
                  let find_start_col line =
                    let expr_start = String.strip expr_str in
                    let expr_first_char =
                      if String.is_empty expr_start then
                        None
                      else
                        Some (String.get expr_start 0)
                    in
                    let rec search_col pos =
                      if pos >= String.length line then
                        None
                      else (
                        match expr_first_char with
                        | Some '(' when Char.equal (String.get line pos) '(' ->
                          (* Found opening parenthesis, check if it matches the expression *)
                          let remaining = String.drop_prefix line pos in
                          let normalized_remaining = normalize remaining in
                            if
                              String.is_prefix
                                normalized_remaining
                                ~prefix:normalized_expr
                            then
                              Some (pos + 1)
                            else
                              search_col (pos + 1)
                        | Some ch when Char.equal (String.get line pos) ch ->
                          (* Found first character, check if it matches *)
                          let remaining = String.drop_prefix line pos in
                          let normalized_remaining = normalize remaining in
                            if
                              String.is_prefix
                                normalized_remaining
                                ~prefix:normalized_expr
                            then
                              Some (pos + 1)
                            else
                              search_col (pos + 1)
                        | _ ->
                          search_col (pos + 1)
                      )
                    in
                      search_col 0
                  in
                    match find_start_col line with
                    | Some col ->
                      Some (line_num, col)
                    | None ->
                      search_lines rest (line_num + 1)
                ) else
                  search_lines rest (line_num + 1)
          in
            search_lines source_lines 1
        in
          (* Print warning to stderr before evaluating the expression *)
          (* Pass stream context if available for better source code display *)
          (match !current_stream with
           | Some stream ->
             let source_lines = stream.recent_input in
             let file_name =
               if stream.repl_mode then
                 "stdin"
               else
                 stream.file_name
             in
             let line_num, col_num =
               match find_expr_position source_lines expr_str with
               | Some (line, col) ->
                 line, col
               | None ->
                 (* Fallback: use current stream position or default *)
                 ( (if stream.repl_mode then
                      1
                    else
                      !(stream.line_num))
                 , !(stream.column) )
             in
               Mlisp_print.Error.print_module_warning
                 ~file_name
                 ~line_number:line_num
                 ~column_number:col_num
                 ?source_lines:
                   (if List.is_empty source_lines then
                      None
                    else
                      Some source_lines)
                 name
                 expr_str
                 warning_msg
           | None ->
             Mlisp_print.Error.print_module_warning name expr_str warning_msg);
          let _ = eval_expr expr module_env in
            ())
  in
  (* Verify all exports exist in module environment *)
  let () =
    List.iter exports ~f:(fun export_name ->
      try Object.lookup (export_name, module_env) |> ignore with
      | Errors.Runtime_error_exn _ ->
        raise (Errors.Runtime_error_exn (Errors.Export_not_found (name, export_name))))
  in
  (* Create final module object with correct exports *)
  let final_module_obj = Object.Module { name; env = module_env; exports } in
  (* Update the module reference in module_env *)
  let () = Object.bind (name, final_module_obj, module_env) |> ignore in
  (* Register the module in the cache for module-cache-stats and module-cached? *)
  let () = Module_cache.register_cached_module name final_module_obj module_env "" in
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
    | Object.ImportAll module_name -> (
      let mod_obj = Object.lookup (module_name, env) in
        match mod_obj with
        | Object.Module _ ->
          mod_obj, module_name
        | _ ->
          raise (Errors.Runtime_error_exn (Errors.Not_a_module module_name)))
    | Object.ImportSelective (module_name, _) -> (
      let mod_obj = Object.lookup (module_name, env) in
        match mod_obj with
        | Object.Module _ ->
          mod_obj, module_name
        | _ ->
          raise (Errors.Runtime_error_exn (Errors.Not_a_module module_name)))
    | Object.ImportAs (module_name, _) -> (
      let mod_obj = Object.lookup (module_name, env) in
        match mod_obj with
        | Object.Module _ ->
          mod_obj, module_name
        | _ ->
          raise (Errors.Runtime_error_exn (Errors.Not_a_module module_name)))
  in
    match module_obj, import_spec with
    | Object.Module { name = _; env = module_env; exports }, Object.ImportAll _ ->
      (* Import all exported symbols *)
      begin
        List.iter exports ~f:(fun export_name ->
          let value = Object.lookup (export_name, module_env) in
            Object.bind (export_name, value, env) |> ignore);
        (* Re-register module in cache if it was cleared *)
        Module_cache.register_cached_module import_name module_obj module_env "";
        module_obj
      end
    | ( Object.Module { name = mod_name; env = module_env; exports }
      , Object.ImportSelective (_, import_names) ) ->
      (* Import only specified symbols *)
      begin
        List.iter import_names ~f:(fun import_name ->
          if List.mem exports import_name ~equal:String.equal then (
            let value = Object.lookup (import_name, module_env) in
              Object.bind (import_name, value, env) |> ignore
          ) else
            raise
              (Errors.Runtime_error_exn (Errors.Export_not_found (mod_name, import_name))));
        (* Re-register module in cache if it was cleared *)
        Module_cache.register_cached_module import_name module_obj module_env "";
        module_obj
      end
    | Object.Module { name = _; env = module_env; exports }, Object.ImportAs (_, alias) ->
      (* Bind the alias to the module object *)
      begin
        Object.bind (alias, module_obj, env) |> ignore;
        (* Import all with namespace prefix *)
        List.iter exports ~f:(fun export_name ->
          let prefixed_name = [%string "%{alias}.%{export_name}"] in
          let value = Object.lookup (export_name, module_env) in
            Object.bind (prefixed_name, value, env) |> ignore);
        (* Re-register module in cache if it was cleared *)
        Module_cache.register_cached_module import_name module_obj module_env "";
        module_obj
      end
    | _ ->
      raise (Errors.Runtime_error_exn (Errors.Not_a_module import_name))

(** Evaluate a load-module expression.

    Loads a module from a file by name. This uses the module loader's
    load_module function which supports circular dependency detection
    and caching.

    @param module_name_expr Expression evaluating to module name (string or symbol)
    @param env Current environment
    @return Unit (module is loaded and bound in environment)
    @raise Errors.Runtime_error_exn if module cannot be found or loaded *)
and eval_load_module module_name_expr env =
  (* Evaluate the module name expression *)
  let module_name_obj = eval_expr module_name_expr env in
  let module_name =
    match module_name_obj with
    | Object.String s -> s
    | Object.Symbol s -> s
    | _ ->
      raise (Errors.Runtime_error_exn (Errors.Module_load_error ("load-module", "requires a string or symbol module name")))
  in
  (* Get default search paths: current directory and modules/ subdirectory *)
  let current_dir = Core_unix.getcwd () in
  let modules_dir = Filename.concat current_dir "modules" in
  let search_paths = [ current_dir; modules_dir ] in

  (* Get cache state for circular dependency detection *)
  let cache_ref = Module_cache.get_global_cache () in
  let state = !cache_ref in

  (* Check for circular dependency *)
  let is_loading = List.exists state.currently_loading ~f:(fun m -> String.equal m module_name) in
  if is_loading then (
    let cycle_path = String.concat ~sep:" -> " (List.rev (module_name :: state.currently_loading)) in
      raise
        (Errors.Runtime_error_exn
           (Errors.Module_load_error
              ( module_name
              , [%string "Circular dependency detected: %{cycle_path}"] )))
  );

  (* Check cache first *)
  (match Hashtbl.find state.cache module_name with
   | Some cached ->
       (* Cache hit - bind the module object to the current environment *)
       Object.bind (module_name, cached.module_object, env) |> ignore;
       cached.module_object
   | None ->
       (* Cache miss - resolve and load the module *)
       let module_file = [%string "%{module_name}.mlisp"] in
       let rec search_path = function
         | [] ->
             raise
               (Errors.Runtime_error_exn
                  (Errors.Module_load_error
                     ( module_name
                     , [%string "Module file '%{module_file}' not found in search paths"] )))
         | path :: rest ->
             let full_path = Filename.concat path module_file in
               match Core_unix.access full_path [ `Exists ] with
               | Ok () ->
                   full_path
               | Error _ ->
                   search_path rest
       in
       let file_path = search_path search_paths in

       (* Add to currently_loading list *)
       cache_ref :=
         { state with currently_loading = module_name :: state.currently_loading };

       (* Load and evaluate the module file *)
       let load_and_cache () =
         try
           let input_channel = In_channel.create file_path in
           let stream =
             Mlisp_utils.Stream_wrapper.make_filestream input_channel ~file_name:file_path
           in
           let rec load_all load_env =
             try
               let ast = stream |> Lexer.read_sexpr |> Ast.build_ast in
               let _, updated_env = eval ast load_env in
                 load_all updated_env
             with
             | Stream.Failure ->
               load_env
             | exn ->
               In_channel.close input_channel;
               raise exn
           in
           let result_env = load_all env in
             In_channel.close input_channel;

           (* Register the module in cache if it was defined *)
           (try
              let module_obj = Object.lookup (module_name, result_env) in
                (match module_obj with
                 | Object.Module { name = _; env = module_env; exports = _ } ->
                     Module_cache.register_cached_module module_name module_obj module_env file_path
                 | _ ->
                     (* Not a module object, but cache anyway *)
                     Module_cache.register_cached_module module_name module_obj result_env file_path)
            with
            | Errors.Runtime_error_exn _ ->
                (* Module not found in result env - that's OK, file might have other content *)
                ());

           (* Remove from currently_loading list *)
           cache_ref :=
             { !cache_ref with
               currently_loading =
                 List.filter state.currently_loading ~f:(fun m -> not (String.equal m module_name))
             };

           Object.Symbol "ok"
         with
         | exn ->
           (* On error, remove from currently_loading list *)
           cache_ref :=
             { !cache_ref with
               currently_loading =
                 List.filter (!cache_ref).currently_loading ~f:(fun m -> not (String.equal m module_name))
             };
           raise exn
       in
         load_and_cache ())

(** Evaluate a module definition at the top level.

    Handles module definitions that appear at the top level of a program.
    Modules are bound to their names in the environment.

    @param name Module name
    @param exports List of exported symbol names
    @param body_exprs List of body expressions
    @param env Current environment
    @return Module object and updated environment *)
and eval_module_def name exports body_exprs env = eval_module name exports body_exprs env

and eval ast env =
  match ast with
  | Object.Defexpr def_expr ->
    eval_def def_expr env
  | Object.ModuleDef (name, exports, body_exprs) ->
    let _, updated_env = eval_module_def name exports body_exprs env in
      Object.Symbol "ok", updated_env
  | expr ->
    eval_expr expr env, env
;;
