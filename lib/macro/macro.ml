(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Mlisp_ast
open Core

(** Macro expansion system for MLisp.

    This module implements the core macro expansion mechanism, which transforms
    macro calls into their expanded forms before evaluation. Macros are expanded
    recursively until no more macro calls remain.
*)

(** Maximum expansion depth to prevent infinite recursion. *)
let max_expansion_depth = 100

(** Check if a symbol is bound to a macro in the environment.

    @param name Symbol name to check
    @param env Environment to search
    @return true if the symbol is bound to a macro, false otherwise
*)
let is_macro name env =
  try
    match Object.lookup (name, env) with
    | Object.Macro _ ->
      true
    | _ ->
      false
  with
  | Errors.Runtime_error_exn _ ->
    false
;;

(** Convert an AST expression back to S-expression format.

    This is used to pass arguments to macros, which operate on S-expressions.
    The macro body will then be evaluated and its result re-parsed.

    @param expr AST expression to convert
    @return S-expression representation
*)
let rec expr_to_sexpr = function
  | Object.Literal v ->
    v
  | Object.Var n ->
    Object.Symbol n
  | Object.If (cond, if_true, if_false) ->
    Object.list_to_pair
      [ Object.Symbol "if"
      ; expr_to_sexpr cond
      ; expr_to_sexpr if_true
      ; expr_to_sexpr if_false
      ]
  | Object.And (left, right) ->
    Object.list_to_pair [ Object.Symbol "and"; expr_to_sexpr left; expr_to_sexpr right ]
  | Object.Or (left, right) ->
    Object.list_to_pair [ Object.Symbol "or"; expr_to_sexpr left; expr_to_sexpr right ]
  | Object.Apply (fn, args) ->
    Object.list_to_pair [ Object.Symbol "apply"; expr_to_sexpr fn; expr_to_sexpr args ]
  | Object.Call (fn, args) ->
    Object.list_to_pair (expr_to_sexpr fn :: List.map ~f:expr_to_sexpr args)
  | Object.Lambda (_name, params, body) ->
    let params_sexpr =
      Object.list_to_pair (List.map ~f:(fun p -> Object.Symbol p) params)
    in
      Object.list_to_pair [ Object.Symbol "lambda"; params_sexpr; expr_to_sexpr body ]
  | Object.Let (kind, bindings, body) ->
    let kind_str =
      match kind with
      | Object.LET ->
        "let"
      | Object.LETSTAR ->
        "let*"
      | Object.LETREC ->
        "letrec"
    in
    let bindings_sexpr =
      Object.list_to_pair
        (List.map bindings ~f:(fun (name, expr) ->
           Object.list_to_pair [ Object.Symbol name; expr_to_sexpr expr ]))
    in
      Object.list_to_pair [ Object.Symbol kind_str; bindings_sexpr; expr_to_sexpr body ]
  | Object.Defexpr def -> (
    match def with
    | Object.Setq (name, expr) ->
      Object.list_to_pair
        [ Object.Symbol "define"; Object.Symbol name; expr_to_sexpr expr ]
    | Object.Defun (name, params, body) ->
      let params_sexpr =
        Object.list_to_pair (List.map ~f:(fun p -> Object.Symbol p) params)
      in
        Object.list_to_pair
          [ Object.Symbol "defun"; Object.Symbol name; params_sexpr; expr_to_sexpr body ]
    | Object.Defmacro (name, params, body) ->
      let params_sexpr =
        Object.list_to_pair (List.map ~f:(fun p -> Object.Symbol p) params)
      in
        Object.list_to_pair
          [ Object.Symbol "defmacro"
          ; Object.Symbol name
          ; params_sexpr
          ; expr_to_sexpr body
          ]
    | Object.Expr expr ->
      expr_to_sexpr expr)
  | Object.ModuleDef (name, exports, body_exprs) ->
    let exports_sexpr =
      Object.list_to_pair
        (Object.Symbol "export" :: List.map ~f:(fun e -> Object.Symbol e) exports)
    in
    let body_sexprs = List.map ~f:expr_to_sexpr body_exprs in
      Object.list_to_pair
        (Object.Symbol "module" :: Object.Symbol name :: exports_sexpr :: body_sexprs)
  | Object.Import import_spec -> (
    match import_spec with
    | Object.ImportAll name ->
      Object.list_to_pair [ Object.Symbol "import"; Object.Symbol name ]
    | Object.ImportSelective (name, symbols) ->
      let symbols_sexpr = List.map ~f:(fun s -> Object.Symbol s) symbols in
        Object.list_to_pair (Object.Symbol "import" :: Object.Symbol name :: symbols_sexpr)
    | Object.ImportAs (name, alias) ->
      Object.list_to_pair
        [ Object.Symbol "import"
        ; Object.Symbol name
        ; Object.Symbol ":as"
        ; Object.Symbol alias
        ])
  | Object.MacroDef (name, params, body) ->
    let params_sexpr =
      Object.list_to_pair (List.map ~f:(fun p -> Object.Symbol p) params)
    in
      Object.list_to_pair
        [ Object.Symbol "defmacro"; Object.Symbol name; params_sexpr; expr_to_sexpr body ]
;;

(** Expand a single macro call.

    This function:
    1. Looks up the macro definition
    2. Converts macro arguments to S-expressions (they are passed unevaluated)
    3. Binds macro parameters to the argument S-expressions in the macro's environment
    4. Evaluates the macro body (which should return an S-expression, typically via quote)
    5. Returns the result as an S-expression to be re-parsed

    @param macro_name Name of the macro to expand
    @param args Arguments to the macro (as AST expressions, converted to S-expressions)
    @param macro_env Macro's definition environment
    @param env Current environment (for looking up the macro)
    @return Expanded S-expression
    @raise Errors.Runtime_error_exn if macro not found or expansion fails
*)
let expand_macro_call macro_name args macro_env env =
  (* Get the macro definition *)
  let macro_obj = Object.lookup (macro_name, env) in
    match macro_obj with
    | Object.Macro (_, param_names, body_expr, _) ->
      (* Convert arguments to S-expressions (they are passed unevaluated to macros) *)
      let arg_sexprs = List.map ~f:expr_to_sexpr args in
      (* Create a new environment for macro expansion, extending the macro's definition environment *)
      let expansion_env = Object.extend_env macro_env in
      (* Bind each parameter to its corresponding argument S-expression *)
      let () =
        try
          List.iter2_exn param_names arg_sexprs ~f:(fun param_name arg_sexpr ->
            Object.bind (param_name, arg_sexpr, expansion_env) |> ignore)
        with
        | Invalid_argument _ ->
          raise
            (Errors.Runtime_error_exn
               (Errors.Not_found
                  [%string
                    "Macro %{macro_name} expects %{Int.to_string (List.length \
                     param_names)} arguments, got %{Int.to_string (List.length \
                     arg_sexprs)}"]))
      in
        (* The macro body expression will be evaluated by the caller (eval_expr) *)
        (* We return the body expression, which will be evaluated to get the S-expression *)
        (* The body should evaluate to an S-expression (typically wrapped in quote) *)
        body_expr
    | _ ->
      raise
        (Errors.Runtime_error_exn
           (Errors.Not_found [%string "%{macro_name} is not a macro"]))
;;

(** Recursively expand all macros in an expression.

    This is the main entry point for macro expansion. It traverses the AST
    and expands any macro calls it finds, recursively expanding the results
    until no more macros remain.

    @param expr Expression to expand
    @param env Current environment
    @param eval_fn Function to evaluate expressions (to evaluate macro bodies)
    @param depth Current expansion depth (to prevent infinite recursion)
    @return Fully expanded expression
*)
let rec expand_expr expr env ~eval_fn ~depth =
  if depth > max_expansion_depth then
    raise
      (Errors.Runtime_error_exn
         (Errors.Not_found
            [%string
              "Macro expansion exceeded maximum depth %{Int.to_string \
               max_expansion_depth}. Possible infinite recursion."]))
  else (
    match expr with
    (* Literals and variables don't need expansion *)
    | Object.Literal _
    | Object.Var _ ->
      expr
    (* Expand conditionals *)
    | Object.If (cond, if_true, if_false) ->
      Object.If
        ( expand_expr cond env ~eval_fn ~depth:(depth + 1)
        , expand_expr if_true env ~eval_fn ~depth:(depth + 1)
        , expand_expr if_false env ~eval_fn ~depth:(depth + 1) )
    (* Expand logical operators *)
    | Object.And (left, right) ->
      Object.And
        ( expand_expr left env ~eval_fn ~depth:(depth + 1)
        , expand_expr right env ~eval_fn ~depth:(depth + 1) )
    | Object.Or (left, right) ->
      Object.Or
        ( expand_expr left env ~eval_fn ~depth:(depth + 1)
        , expand_expr right env ~eval_fn ~depth:(depth + 1) )
    (* Expand function calls - check if the function is actually a macro *)
    | Object.Call (Object.Var fn_name, args) when is_macro fn_name env -> (
      (* This is a macro call - expand it *)
      let macro_obj = Object.lookup (fn_name, env) in
        match macro_obj with
        | Object.Macro (_, param_names, body_expr, macro_env) ->
          (* Convert arguments to S-expressions (they are passed unevaluated to macros) *)
          let arg_sexprs = List.map ~f:expr_to_sexpr args in
          (* Create a new environment for macro expansion, extending the macro's definition environment *)
          let expansion_env = Object.extend_env macro_env in
          (* Bind each parameter to its corresponding argument S-expression *)
          let () =
            try
              List.iter2_exn param_names arg_sexprs ~f:(fun param_name arg_sexpr ->
                Object.bind (param_name, arg_sexpr, expansion_env) |> ignore)
            with
            | Invalid_argument _ ->
              raise
                (Errors.Runtime_error_exn
                   (Errors.Not_found
                      [%string
                        "Macro %{fn_name} expects %{Int.to_string (List.length \
                         param_names)} arguments, got %{Int.to_string (List.length \
                         arg_sexprs)}"]))
          in
          (* Evaluate the macro body in the expansion environment *)
          (* The body should evaluate to an S-expression (wrapped in quote) *)
          let result_sexpr =
            match eval_fn body_expr expansion_env with
            | Object.Quote sexpr ->
              sexpr
            | sexpr ->
              sexpr
          in
          (* Re-parse the expanded S-expression into an AST *)
          let expanded_expr = Ast.build_ast result_sexpr in
            (* Recursively expand the result *)
            expand_expr expanded_expr env ~eval_fn ~depth:(depth + 1)
        | _ ->
          expr)
    (* Expand regular function calls *)
    | Object.Call (fn, args) ->
      Object.Call
        ( expand_expr fn env ~eval_fn ~depth:(depth + 1)
        , List.map args ~f:(fun arg -> expand_expr arg env ~eval_fn ~depth:(depth + 1)) )
    (* Expand apply *)
    | Object.Apply (fn, args) ->
      Object.Apply
        ( expand_expr fn env ~eval_fn ~depth:(depth + 1)
        , expand_expr args env ~eval_fn ~depth:(depth + 1) )
    (* Expand lambda - expand body but not parameters *)
    | Object.Lambda (name, params, body) ->
      Object.Lambda (name, params, expand_expr body env ~eval_fn ~depth:(depth + 1))
    (* Expand let bindings *)
    | Object.Let (kind, bindings, body) ->
      let expanded_bindings =
        List.map bindings ~f:(fun (name, expr) ->
          name, expand_expr expr env ~eval_fn ~depth:(depth + 1))
      in
        Object.Let
          (kind, expanded_bindings, expand_expr body env ~eval_fn ~depth:(depth + 1))
    (* Expand definitions *)
    | Object.Defexpr def -> (
      match def with
      | Object.Setq (name, expr) ->
        Object.Defexpr
          (Object.Setq (name, expand_expr expr env ~eval_fn ~depth:(depth + 1)))
      | Object.Defun (name, params, body) ->
        Object.Defexpr
          (Object.Defun (name, params, expand_expr body env ~eval_fn ~depth:(depth + 1)))
      | Object.Defmacro (_name, _params, _body) ->
        (* Macro definitions themselves are not expanded - they define expansion rules *)
        expr
      | Object.Expr expr ->
        Object.Defexpr (Object.Expr (expand_expr expr env ~eval_fn ~depth:(depth + 1))))
    (* Expand module definitions *)
    | Object.ModuleDef (name, exports, body_exprs) ->
      Object.ModuleDef
        ( name
        , exports
        , List.map body_exprs ~f:(fun e -> expand_expr e env ~eval_fn ~depth:(depth + 1))
        )
    (* Imports don't need expansion *)
    | Object.Import _ ->
      expr
    | Object.MacroDef (_name, _params, _body) ->
      (* Macro definitions are not expanded *)
      expr
  )
;;

(** Main entry point: expand all macros in an expression.

    @param expr Expression to expand
    @param env Current environment
    @param eval_fn Function to evaluate expressions (needed to evaluate macro bodies)
    @return Fully expanded expression
*)
let expand expr env ~eval_fn = expand_expr expr env ~eval_fn ~depth:0
