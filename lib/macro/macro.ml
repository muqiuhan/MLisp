(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Mlisp_ast
open Core

(** {1 Macro Expansion System for MLisp}

    This module implements the core macro expansion mechanism, which transforms
    macro calls into their expanded forms before evaluation. Macros are expanded
    recursively until no more macro calls remain.

    The expansion process:
    {ul
      {- Traverse the AST looking for macro calls}
      {- When a macro call is found, evaluate its body with unevaluated arguments}
      {- Re-parse the result and continue expanding}
      {- Repeat until no macros remain}
    }
*)

(** {2 Constants} *)

(** Maximum expansion depth to prevent infinite recursion.

    This limit protects against macros that expand to themselves or create
    infinite expansion loops. When this depth is exceeded, a runtime error
    is raised.
*)
let max_expansion_depth = 100

(** {2 Macro Detection} *)

(** Check if a symbol is bound to a macro in the environment.

    This function is used during pattern matching on function calls to determine
    whether a call should be macro-expanded or evaluated normally.

    @param name Symbol name to check
    @param env Environment to search
    @return [true] if the symbol is bound to a macro, [false] otherwise
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

(** {2 AST to S-expression Conversion} *)

(** Convert an AST expression back to S-expression format.

    This function is used to pass arguments to macros. Macros operate on
    S-expressions (not AST nodes) so that they can manipulate code as data.
    After a macro body produces an S-expression result, it is re-parsed
    into an AST via [Ast.build_ast].

    The conversion preserves the structure of the original expression while
    converting AST nodes back into their S-expression representation.

    @param expr AST expression to convert
    @return S-expression representation (as [lobject])
*)
let rec expr_to_sexpr = function
  (** Literals are already values - pass through unchanged *)
  | Object.Literal v ->
    v

  (** Variables become symbols *)
  | Object.Var n ->
    Object.Symbol n

  (** If expressions: (if condition true-branch false-branch) *)
  | Object.If (cond, if_true, if_false) ->
    Object.list_to_pair
      [ Object.Symbol "if"
      ; expr_to_sexpr cond
      ; expr_to_sexpr if_true
      ; expr_to_sexpr if_false
      ]

  (** Logical AND: (and left right) *)
  | Object.And (left, right) ->
    Object.list_to_pair [ Object.Symbol "and"; expr_to_sexpr left; expr_to_sexpr right ]

  (** Logical OR: (or left right) *)
  | Object.Or (left, right) ->
    Object.list_to_pair [ Object.Symbol "or"; expr_to_sexpr left; expr_to_sexpr right ]

  (** Apply function: (apply function arguments) *)
  | Object.Apply (fn, args) ->
    Object.list_to_pair [ Object.Symbol "apply"; expr_to_sexpr fn; expr_to_sexpr args ]

  (** Function call: (function arg1 arg2 ...) *)
  | Object.Call (fn, args) ->
    Object.list_to_pair (expr_to_sexpr fn :: List.map ~f:expr_to_sexpr args)

  (** Lambda expression: (lambda (params...) body) *)
  | Object.Lambda (_name, params, body) ->
    let params_sexpr =
      Object.list_to_pair (List.map ~f:(fun p -> Object.Symbol p) params)
    in
      Object.list_to_pair [ Object.Symbol "lambda"; params_sexpr; expr_to_sexpr body ]

  (** Let binding: (let* | let | letrec bindings body) *)
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

  (** Definition forms: define, defun, defmacro *)
  | Object.Defexpr def -> (
    match def with
    (** Variable definition: (define name value) *)
    | Object.Setq (name, expr) ->
      Object.list_to_pair
        [ Object.Symbol "define"; Object.Symbol name; expr_to_sexpr expr ]

    (** Function definition: (defun name (params...) body) *)
    | Object.Defun (name, params, body) ->
      let params_sexpr =
        Object.list_to_pair (List.map ~f:(fun p -> Object.Symbol p) params)
      in
        Object.list_to_pair
          [ Object.Symbol "defun"; Object.Symbol name; params_sexpr; expr_to_sexpr body ]

    (** Macro definition: (defmacro name (params...) body) *)
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

    (** Bare expression wrapper *)
    | Object.Expr expr ->
      expr_to_sexpr expr)

  (** Module definition: (module name (exports...) body...) *)
  | Object.ModuleDef (name, exports, body_exprs) ->
    let exports_sexpr =
      Object.list_to_pair
        (Object.Symbol "export" :: List.map ~f:(fun e -> Object.Symbol e) exports)
    in
    let body_sexprs = List.map ~f:expr_to_sexpr body_exprs in
      Object.list_to_pair
        (Object.Symbol "module" :: Object.Symbol name :: exports_sexpr :: body_sexprs)

  (** Import forms *)
  | Object.Import import_spec -> (
    match import_spec with
    (** Import all: (import module-name) *)
    | Object.ImportAll name ->
      Object.list_to_pair [ Object.Symbol "import"; Object.Symbol name ]

    (** Selective import: (import module-name symbol1 symbol2 ...) *)
    | Object.ImportSelective (name, symbols) ->
      let symbols_sexpr = List.map ~f:(fun s -> Object.Symbol s) symbols in
        Object.list_to_pair (Object.Symbol "import" :: Object.Symbol name :: symbols_sexpr)

    (** Import with alias: (import module-name :as alias) *)
    | Object.ImportAs (name, alias) ->
      Object.list_to_pair
        [ Object.Symbol "import"
        ; Object.Symbol name
        ; Object.Symbol ":as"
        ; Object.Symbol alias
        ])

  (** Macro definition (alternate form): (defmacro name (params...) body) *)
  | Object.MacroDef (name, params, body) ->
    let params_sexpr =
      Object.list_to_pair (List.map ~f:(fun p -> Object.Symbol p) params)
    in
      Object.list_to_pair
        [ Object.Symbol "defmacro"; Object.Symbol name; params_sexpr; expr_to_sexpr body ]

  (** Load module from file: (load-module "module-name") *)
  | Object.LoadModule module_name_expr ->
      let module_name_sexp = expr_to_sexpr module_name_expr in
        Object.list_to_pair [ Object.Symbol "load-module"; module_name_sexp ]
;;

(** {2 Single Macro Call Expansion} *)

(** Expand a single macro call (internal helper).

    This function performs the low-level work of expanding one macro call:
    1. Looks up the macro definition from the environment
    2. Converts macro arguments to S-expressions (passed unevaluated)
    3. Binds macro parameters to the argument S-expressions in a new environment
    4. Returns the macro body expression for evaluation

    Note: This function returns the body expression, not the expanded result.
    The caller must evaluate the body to get the actual S-expression result.

    @param macro_name Name of the macro to expand
    @param args Arguments to the macro (as AST expressions)
    @param macro_env The macro's definition environment (for lexical scoping)
    @param env Current environment (for looking up the macro)
    @return The macro body expression to be evaluated
    @raise Errors.Runtime_error_exn if macro not found or argument count mismatch
*)
let expand_macro_call macro_name args macro_env env =
  (* Get the macro definition from the environment *)
  let macro_obj = Object.lookup (macro_name, env) in
    match macro_obj with
    | Object.Macro (_, param_names, body_expr, _) ->
      (** Convert arguments to S-expressions.

          Macro arguments are passed unevaluated, so we convert them directly
          to S-expressions without evaluating them first. This allows macros
          to manipulate their arguments as code rather than values.
      *)
      let arg_sexprs = List.map ~f:expr_to_sexpr args in

      (** Create expansion environment.

          The macro's body is evaluated in an environment that extends the
          macro's definition environment. This provides lexical scoping for
          any free variables in the macro body.
      *)
      let expansion_env = Object.extend_env macro_env in

      (** Bind parameters to argument S-expressions.

          Each parameter in the macro definition is bound to the corresponding
          argument S-expression. These bindings are added to the expansion
          environment for use during macro body evaluation.
      *)
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
        (** Return the macro body expression.

            The caller will evaluate this expression in the expansion environment
            to obtain the actual S-expression result. This result will then be
            re-parsed into an AST for further expansion or evaluation.
        *)
        body_expr
    | _ ->
      raise
        (Errors.Runtime_error_exn
           (Errors.Not_found [%string "%{macro_name} is not a macro"]))
;;

(** {2 Full Recursive Expansion} *)

(** Recursively expand all macros in an expression.

    This is the core expansion function. It traverses the entire AST and
    expands every macro call it finds. After expanding a macro, the result
    is re-parsed and recursively expanded again until no macros remain.

    The [depth] parameter prevents infinite expansion by limiting how many
    times a single expression can be expanded.

    @param expr Expression to expand
    @param env Current environment (for macro lookup)
    @param eval_fn Function to evaluate expressions (for macro bodies)
    @param depth Current expansion depth (increments with each recursive call)
    @return Fully expanded expression with all macros transformed
    @raise Errors.Runtime_error_exn if maximum depth exceeded
*)
let rec expand_expr expr env ~eval_fn ~depth =
  (** Guard against infinite expansion.

      When a macro expands to itself or creates a cycle, this check prevents
      infinite recursion by throwing an error when the depth limit is reached.
  *)
  if depth > max_expansion_depth then
    raise
      (Errors.Runtime_error_exn
         (Errors.Not_found
            [%string
              "Macro expansion exceeded maximum depth %{Int.to_string \
               max_expansion_depth}. Possible infinite recursion."]))
  else (
    match expr with
    (** ======================================================================
        {3 Atomic Expressions}

        Literals (numbers, strings, booleans, nil) and variables don't contain
        any macro calls, so they pass through unchanged.
        ====================================================================== *)

    (** Literal values: numbers, strings, booleans, nil.

        These are self-evaluating values that cannot contain macro calls.
    *)
    | Object.Literal _
    (** Variable references.

        A variable name itself is not a macro call. The variable might be
        bound to a macro, but the reference itself doesn't trigger expansion.
        Macro expansion only happens at call sites.
    *)
    | Object.Var _ ->
      expr

    (** ======================================================================
        {3 Conditional Expressions}

        Conditional forms may contain macro calls in their sub-expressions,
        so we recursively expand each branch.
        ====================================================================== *)

    (** If expression: (if condition true-branch false-branch)

        All three sub-expressions may contain macro calls, so each is
        recursively expanded. The structure of the if expression is preserved.
    *)
    | Object.If (cond, if_true, if_false) ->
      Object.If
        ( expand_expr cond env ~eval_fn ~depth:(depth + 1)
        , expand_expr if_true env ~eval_fn ~depth:(depth + 1)
        , expand_expr if_false env ~eval_fn ~depth:(depth + 1) )

    (** ======================================================================
        {3 Logical Operators}

        Short-circuit operators may contain macro calls in their operands.
        Both operands are expanded (the short-circuit behavior happens during
        evaluation, not expansion).
        ====================================================================== *)

    (** Logical AND: (and left right)

        Both the left and right operands are recursively expanded. The and
        form itself is preserved.
    *)
    | Object.And (left, right) ->
      Object.And
        ( expand_expr left env ~eval_fn ~depth:(depth + 1)
        , expand_expr right env ~eval_fn ~depth:(depth + 1) )

    (** Logical OR: (or left right)

        Both the left and right operands are recursively expanded. The or
        form itself is preserved.
    *)
    | Object.Or (left, right) ->
      Object.Or
        ( expand_expr left env ~eval_fn ~depth:(depth + 1)
        , expand_expr right env ~eval_fn ~depth:(depth + 1) )

    (** ======================================================================
        {3 Macro Calls}

        This is the key pattern: when we see a call to a function that is
        bound to a macro, we expand it. The expansion process:
        1. Convert arguments to S-expressions (unevaluated)
        2. Bind parameters in a fresh environment
        3. Evaluate the macro body to get an S-expression
        4. Re-parse the S-expression into an AST
        5. RECURSIVELY expand the result (crucial for nested macros)
        ====================================================================== *)

    (** Macro call: (macro-name arg1 arg2 ...)

        The guard [when is_macro fn_name env] ensures this pattern only matches
        when the called function is actually a macro. This is the heart of the
        macro expansion system.
    *)
    | Object.Call (Object.Var fn_name, args) when is_macro fn_name env -> (
      let macro_obj = Object.lookup (fn_name, env) in
        match macro_obj with
        | Object.Macro (_, param_names, body_expr, macro_env) ->
          (** Convert arguments to S-expressions (unevaluated).

              Unlike function calls, macro arguments are not evaluated before
              being passed to the macro. This allows macros to manipulate their
              arguments as code.
          *)
          let arg_sexprs = List.map ~f:expr_to_sexpr args in

          (** Create a fresh expansion environment.

              The environment extends the macro's definition environment,
              providing lexical scoping for free variables in the macro body.
          *)
          let expansion_env = Object.extend_env macro_env in

          (** Bind parameters to argument S-expressions.

              Each parameter is bound to its corresponding argument S-expression
              in the expansion environment. These bindings are used when the
              macro body is evaluated.
          *)
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

          (** Evaluate the macro body.

              The macro body is evaluated in the expansion environment, which
              contains the parameter bindings. The result should be an
              S-expression (typically via a quote form).
          *)
          let result_sexpr =
            match eval_fn body_expr expansion_env with
            (** Strip the quote wrapper if present.

                When a macro body returns '(foo bar), we want just the
                (foo bar) S-expression, not the Quote wrapper.
            *)
            | Object.Quote sexpr ->
              sexpr
            | sexpr ->
              sexpr
          in

          (** Re-parse the S-expression into an AST.

              The macro returns an S-expression, but we need an AST for
              further processing. [Ast.build_ast] parses the S-expression
              back into an AST expression.
          *)
          let expanded_expr = Ast.build_ast result_sexpr in

            (** RECURSIVELY expand the result.

                This is the key difference that makes [expand_expr] fully
                recursive. After expanding a macro, we expand the result again,
                which handles:
                - Nested macros (macros that expand to other macro calls)
                - Macros that expand to themselves
                - Multi-level macro expansion

                Without this recursion, macros would only expand one level.
            *)
            expand_expr expanded_expr env ~eval_fn ~depth:(depth + 1)

        | _ ->
          expr)

    (** ======================================================================
        {3 Regular Function Calls}

        Function calls are not macros, but their sub-expressions may contain
        macro calls. We expand the function position and each argument.
        ====================================================================== *)

    (** Regular function call: (function arg1 arg2 ...)

        The function position and each argument are recursively expanded.
        The call structure itself is preserved.
    *)
    | Object.Call (fn, args) ->
      Object.Call
        ( expand_expr fn env ~eval_fn ~depth:(depth + 1)
        , List.map args ~f:(fun arg -> expand_expr arg env ~eval_fn ~depth:(depth + 1)) )

    (** ======================================================================
        {3 Apply Form}

        The apply form calls a function with a list of arguments. Both the
        function and the argument list may contain macro calls.
        ====================================================================== *)

    (** Apply: (apply function argument-list)

        Both the function expression and the argument list expression are
        recursively expanded.
    *)
    | Object.Apply (fn, args) ->
      Object.Apply
        ( expand_expr fn env ~eval_fn ~depth:(depth + 1)
        , expand_expr args env ~eval_fn ~depth:(depth + 1) )

    (** ======================================================================
        {3 Lambda Expressions}

        Lambda expressions define functions. The parameters are not expanded
        (they are just names), but the body may contain macro calls.
        ====================================================================== *)

    (** Lambda: (lambda (params...) body)

        The parameter list is left unchanged (parameters are just symbols).
        The body expression is recursively expanded.
    *)
    | Object.Lambda (name, params, body) ->
      Object.Lambda (name, params, expand_expr body env ~eval_fn ~depth:(depth + 1))

    (** ======================================================================
        {3 Let Bindings}

        Let forms bind variables to values. Both the binding expressions and
        the body may contain macro calls.
        ====================================================================== *)

    (** Let binding: (let* | let | letrec ((name value) ...) body)

        Each binding value expression is recursively expanded. The binding
        names are left unchanged (they are just symbols). The body expression
        is also expanded.
    *)
    | Object.Let (kind, bindings, body) ->
      let expanded_bindings =
        List.map bindings ~f:(fun (name, expr) ->
          name, expand_expr expr env ~eval_fn ~depth:(depth + 1))
      in
        Object.Let
          (kind, expanded_bindings, expand_expr body env ~eval_fn ~depth:(depth + 1))

    (** ======================================================================
        {3 Definition Forms}

        Definitions bind names to values or functions. The value expression
        may contain macro calls.
        ====================================================================== *)

    | Object.Defexpr def -> (
      match def with
      (** Variable assignment: (define name value)

          The value expression is recursively expanded.
      *)
      | Object.Setq (name, expr) ->
        Object.Defexpr
          (Object.Setq (name, expand_expr expr env ~eval_fn ~depth:(depth + 1)))

      (** Function definition: (defun name (params...) body)

          The parameter list is left unchanged. The body expression is
          recursively expanded.
      *)
      | Object.Defun (name, params, body) ->
        Object.Defexpr
          (Object.Defun (name, params, expand_expr body env ~eval_fn ~depth:(depth + 1)))

      (** Macro definition: (defmacro name (params...) body)

          Macro definitions themselves are NOT expanded. A macro definition
          creates a macro object in the environment; it doesn't expand to
          anything. The macro body is stored unevaluated and will only be
          evaluated when the macro is used.
      *)
      | Object.Defmacro (_name, _params, _body) ->
        expr

      (** Bare expression wrapper

          The wrapped expression is recursively expanded.
      *)
      | Object.Expr expr ->
        Object.Defexpr (Object.Expr (expand_expr expr env ~eval_fn ~depth:(depth + 1))))

    (** ======================================================================
        {3 Module Definitions}

        Module definitions contain a body of expressions. Each expression
        in the body may contain macro calls.
        ====================================================================== *)

    (** Module definition: (module name (exports...) body...)

        The module name and exports are left unchanged (they are just symbols
        and strings). Each expression in the body is recursively expanded.
    *)
    | Object.ModuleDef (name, exports, body_exprs) ->
      Object.ModuleDef
        ( name
        , exports
        , List.map body_exprs ~f:(fun e -> expand_expr e env ~eval_fn ~depth:(depth + 1))
        )

    (** ======================================================================
        {3 Import Forms}

        Import forms reference modules and don't contain macro calls that
        need expansion.
        ====================================================================== *)

    (** Import: (import module-name) or variants

        Import forms are not expanded. They are processed during the
        compilation/evaluation phase, not during macro expansion.
    *)
    | Object.Import _ ->
      expr

    (** Load module: (load-module "module-name")

        Like import, load-module is not expanded. It's processed during
        the evaluation phase.
    *)
    | Object.LoadModule _ ->
      expr

    (** ======================================================================
        {3 Macro Definitions (Alternate Form)}

        Like Defmacro above, macro definitions are not expanded.
        ====================================================================== *)

    | Object.MacroDef (_name, _params, _body) ->
      expr
  )
;;

(** Main entry point: expand all macros in an expression.

    This function initializes the expansion process with depth=0 and
    recursively expands all macros until none remain.

    @param expr Expression to expand
    @param env Current environment
    @param eval_fn Function to evaluate expressions (needed for macro bodies)
    @return Fully expanded expression
*)
let expand expr env ~eval_fn = expand_expr expr env ~eval_fn ~depth:0

(** {2 Single-Step Expansion (for debugging)} *)

(** Expand only the outermost macro call (non-recursive).

    This function is similar to [expand_expr] but with a crucial difference:
    after expanding a macro, it does NOT recursively expand the result.

    This is used for debugging (via [macroexpand-1]) to see what a single
    macro expansion step produces, without expanding nested macros.

    The function returns a tuple:
    - The expanded (or unchanged) expression
    - A boolean flag indicating whether any expansion occurred

    @param expr Expression to expand
    @param env Current environment
    @param eval_fn Function to evaluate expressions (for macro bodies)
    @return A tuple [(expanded_expr, expanded_flag)]
*)
let rec expand_1_expr expr env ~eval_fn =
  match expr with
  (** ======================================================================
      {3 Atomic Expressions}

      Literals and variables cannot contain macro calls, so they are
      returned unchanged with [expanded_flag = false].
      ====================================================================== *)

  | Object.Literal _
  | Object.Var _ ->
    (expr, false)

  (** ======================================================================
      {3 Conditional Expressions}

      We recursively traverse the sub-expressions to find and expand any
      macro calls. The flag is [true] if ANY branch expanded something.
      ====================================================================== *)

  (** If expression: (if condition true-branch false-branch)

      Each branch is processed with [expand_1_expr]. If any branch
      expands a macro, the overall flag becomes [true].
  *)
  | Object.If (cond, if_true, if_false) ->
    let (c_exp, c_flag) = expand_1_expr cond env ~eval_fn in
    let (t_exp, t_flag) = expand_1_expr if_true env ~eval_fn in
    let (f_exp, f_flag) = expand_1_expr if_false env ~eval_fn in
    (Object.If (c_exp, t_exp, f_exp), c_flag || t_flag || f_flag)

  (** ======================================================================
      {3 Logical Operators}

      Both operands are traversed for macro calls.
      ====================================================================== *)

  (** Logical AND: (and left right) *)
  | Object.And (left, right) ->
    let (l_exp, l_flag) = expand_1_expr left env ~eval_fn in
    let (r_exp, r_flag) = expand_1_expr right env ~eval_fn in
    (Object.And (l_exp, r_exp), l_flag || r_flag)

  (** Logical OR: (or left right) *)
  | Object.Or (left, right) ->
    let (l_exp, l_flag) = expand_1_expr left env ~eval_fn in
    let (r_exp, r_flag) = expand_1_expr right env ~eval_fn in
    (Object.Or (l_exp, r_exp), l_flag || r_flag)

  (** ======================================================================
      {3 Macro Calls (CRITICAL DIFFERENCE)}

      When we encounter a macro call, we expand it ONCE and STOP.
      The result is NOT recursively expanded, which is the key difference
      from [expand_expr].
      ====================================================================== *)

  (** Macro call: (macro-name arg1 arg2 ...)

      This pattern matches calls to functions that are bound to macros.
      The macro is expanded, but the result is NOT recursively expanded.
  *)
  | Object.Call (Object.Var fn_name, args) when is_macro fn_name env ->
    let macro_obj = Object.lookup (fn_name, env) in
    (match macro_obj with
     | Object.Macro (_, param_names, body_expr, macro_env) ->
         (** Convert arguments to S-expressions (unevaluated). *)
         let arg_sexprs = List.map ~f:expr_to_sexpr args in

         (** Create expansion environment. *)
         let expansion_env = Object.extend_env macro_env in

         (** Bind parameters to arguments. *)
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

         (** Evaluate macro body to get S-expression result. *)
         let result_sexpr =
           match eval_fn body_expr expansion_env with
           | Object.Quote sexpr ->
             sexpr
           | sexpr ->
             sexpr
         in

         (** Re-parse into AST. *)
         let expanded_expr = Ast.build_ast result_sexpr in

           (** KEY DIFFERENCE: Do NOT recursively expand the result.

               Unlike [expand_expr], we return the expanded expression directly
               without calling [expand_1_expr] on it again. This means that if
               the expanded form contains another macro call, it will remain
               unexpanded, which is exactly what we want for single-step
               expansion.
           *)
           (expanded_expr, true)

     | _ ->
       (expr, false))

  (** ======================================================================
      {3 Regular Function Calls}

      The function position and each argument are traversed for macro calls.
      This allows macros to be found in operator position (higher-order
      functions that return macro names, etc.).
      ====================================================================== *)

  (** Regular function call: (function arg1 arg2 ...) *)
  | Object.Call (fn, args) ->
    (** Expand the function position. *)
    let (fn_exp, fn_flag) = expand_1_expr fn env ~eval_fn in

    (** Expand each argument and collect the results. *)
    let args_expanded = List.map args ~f:(fun arg -> expand_1_expr arg env ~eval_fn) in

    (** Helper to split a list of tuples into two lists. *)
    let rec split_pairs = function
      | [] -> [], []
      | (e, b) :: rest ->
          let es, bs = split_pairs rest in
          e :: es, b :: bs
    in

    (** Separate the expanded expressions from the flags. *)
    let (args_exps, args_flags) = split_pairs args_expanded in

    (** The flag is true if the function position OR any argument expanded. *)
    (Object.Call (fn_exp, args_exps), fn_flag || List.exists args_flags ~f:Fn.id)

  (** ======================================================================
      {3 Apply Form}

      The function and argument list are traversed for macro calls.
      ====================================================================== *)

  (** Apply: (apply function argument-list) *)
  | Object.Apply (fn, args) ->
    let (fn_exp, fn_flag) = expand_1_expr fn env ~eval_fn in
    let (args_exp, args_flag) = expand_1_expr args env ~eval_fn in
    (Object.Apply (fn_exp, args_exp), fn_flag || args_flag)

  (** ======================================================================
      {3 Lambda Expressions}

      The body may contain macro calls, but parameters are just names.
      ====================================================================== *)

  (** Lambda: (lambda (params...) body) *)
  | Object.Lambda (name, params, body) ->
    let (body_exp, body_flag) = expand_1_expr body env ~eval_fn in
    (Object.Lambda (name, params, body_exp), body_flag)

  (** ======================================================================
      {3 Let Bindings}

      The binding value expressions and body may contain macro calls.
      Binding names are left unchanged.
      ====================================================================== *)

  (** Let binding: (let* | let | letrec ((name value) ...) body) *)
  | Object.Let (kind, bindings, body) ->
    (** Expand each binding value expression. *)
    let bindings_result = List.map bindings ~f:(fun (n, e) ->
      let (e_exp, e_flag) = expand_1_expr e env ~eval_fn in
      ((n, e_exp), e_flag)) in

    (** Separate the bindings from the flags. *)
    let bindings_exp = List.map bindings_result ~f:fst in
    let bindings_flags = List.map bindings_result ~f:snd in

    (** Expand the body expression. *)
    let (body_exp, body_flag) = expand_1_expr body env ~eval_fn in

    (** The flag is true if any binding OR the body expanded. *)
    (Object.Let (kind, bindings_exp, body_exp),
     List.exists bindings_flags ~f:Fn.id || body_flag)

  (** ======================================================================
      {3 Definition Forms}

      The value expression may contain macro calls.
      ====================================================================== *)

  | Object.Defexpr def ->
    let (def_exp, def_flag) = expand_1_def def env ~eval_fn in
    (Object.Defexpr def_exp, def_flag)

  (** ======================================================================
      {3 Module Definitions}

      Each body expression may contain macro calls.
      ====================================================================== *)

  (** Module definition: (module name (exports...) body...) *)
  | Object.ModuleDef (name, exports, body_exprs) ->
    (** Helper to split a list of tuples. *)
    let rec split_pairs = function
      | [] -> [], []
      | (e, b) :: rest ->
          let es, bs = split_pairs rest in
          e :: es, b :: bs
    in

    (** Expand each body expression. *)
    let body_expanded = List.map body_exprs ~f:(fun e -> expand_1_expr e env ~eval_fn) in

    (** Separate expressions from flags. *)
    let (body_exps, body_flags) = split_pairs body_expanded in

    (** The flag is true if any body expression expanded. *)
    (Object.ModuleDef (name, exports, body_exps), List.exists body_flags ~f:Fn.id)

  (** ======================================================================
      {3 Import Forms}

      Imports don't contain macro calls to expand.
      ====================================================================== *)

  | Object.Import _ ->
    (expr, false)

  (** Load module: (load-module "module-name")

      Load module forms don't contain macro calls to expand.
  *)
  | Object.LoadModule _ ->
    (expr, false)

  (** ======================================================================
      {3 Macro Definitions}

      Macro definitions are not expanded.
      ====================================================================== *)

  | Object.MacroDef _ ->
    (expr, false)

(** Helper for expanding definitions during single-step expansion.

    @param def The definition to expand
    @param env Current environment
    @param eval_fn Evaluation function
    @return [(expanded_def, expanded_flag)]
*)
and expand_1_def def env ~eval_fn =
  match def with
  (** Variable assignment: (define name value) *)
  | Object.Setq (name, expr) ->
    let (e_exp, e_flag) = expand_1_expr expr env ~eval_fn in
    (Object.Setq (name, e_exp), e_flag)

  (** Function definition: (defun name (params...) body) *)
  | Object.Defun (name, params, body) ->
    let (body_exp, body_flag) = expand_1_expr body env ~eval_fn in
    (Object.Defun (name, params, body_exp), body_flag)

  (** Macro definition: not expanded *)
  | Object.Defmacro _ ->
    (def, false)

  (** Bare expression wrapper *)
  | Object.Expr e ->
    let (e_exp, e_flag) = expand_1_expr e env ~eval_fn in
    (Object.Expr e_exp, e_flag)

(** Public entry point for single-step expansion.

    This function discards the expansion flag and returns only the
    expanded expression. It is used by the [macroexpand-1] special form
    in the evaluator.

    @param expr Expression to expand
    @param env Current environment
    @param eval_fn Function to evaluate expressions
    @return Expanded expression (single step only)
*)
let expand_1 expr env ~eval_fn = fst (expand_1_expr expr env ~eval_fn)
