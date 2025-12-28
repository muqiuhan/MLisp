(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core

let rec assert_unique : string list -> unit = function
  | [] ->
    ()
  | x :: xs ->
    if List.mem xs x ~equal:String.equal then
      raise (Errors.Parse_error_exn (Unique_error x))
    else
      assert_unique xs
;;

let assert_unique_args : Object.lobject -> string list =
  fun args ->
  let names =
    List.map
      ~f:(function
        | Object.Symbol s ->
          s
        | _ ->
          raise
            (Errors.Parse_error_exn
               (Type_error "(declare-expr symbol-name (formals) body)")))
      (Object.pair_to_list args)
  in
  let () = assert_unique names in
    names
;;

let let_kinds : (string * Object.let_kind) list =
  [ "let", Object.LET; "let*", Object.LETSTAR; "letrec", Object.LETREC ]
;;

let valid_let : string -> bool =
  fun s -> List.Assoc.mem ~equal:(fun k s -> String.equal k s) let_kinds s
;;

let to_kind : string -> Object.let_kind =
  fun s -> List.Assoc.find_exn ~equal:(fun k s -> String.equal k s) let_kinds s
;;

let rec build_ast : Object.lobject -> Object.expr =
  fun sexpr ->
  match sexpr with
  | Object.Primitive _
  | Object.Closure _
  | Object.Module _ ->
    raise Errors.This_can't_happen_exn
  | Object.Fixnum _
  | Object.Float _
  | Object.Boolean _
  | Object.Quote _
  | Object.String _
  | Object.Record _
  | Object.Nil ->
    literal_expr sexpr
  | Object.Symbol s ->
    symbol_expr s
  | Object.Pair _ when Object.is_list sexpr -> (
    match Object.pair_to_list sexpr with
    | [ Object.Symbol "if"; cond; if_true; if_false ] ->
      if_expr cond if_true if_false
    | Object.Symbol "cond" :: conditions ->
      cond_to_if conditions
    | [ Object.Symbol "and"; cond_x; cond_y ] ->
      and_expr cond_x cond_y
    | [ Object.Symbol "or"; cond_x; cond_y ] ->
      or_expr cond_x cond_y
    | [ Object.Symbol "`"; expr ] ->
      quote_expr expr
    | [ Object.Symbol "quote"; expr ] ->
      quote_expr expr
    | [ Object.Symbol "define"; Object.Symbol name; expr ] ->
      setq_expr name expr
    | Object.Symbol "lambda" :: args :: body_exprs when Object.is_list args ->
      (* Lambda can have multiple body expressions *)
      lambda_expr args (Object.list_to_pair body_exprs)
    | [ Object.Symbol "apply"; fn_expr; args ] ->
      apply_expr fn_expr args
    | [ Object.Symbol "defun"; Object.Symbol fn_name; args; body ] ->
      defun_expr fn_name args body
    | Object.Symbol "module" :: Object.Symbol name :: exports :: body_exprs
      when Object.is_list exports ->
      module_expr name exports body_exprs
    | Object.Symbol "import" :: import_args ->
      import_expr import_args
    | [ Object.Symbol s; bindings; expr ] when Object.is_list bindings && valid_let s ->
      let_expr s bindings expr
    | fn_expr :: args ->
      call_expr fn_expr args
    | [] ->
      raise (Errors.Parse_error_exn Poorly_formed_expression))
  | Pair _ ->
    Object.Literal sexpr

and literal_expr : Object.lobject -> Object.expr = fun sexpr -> Object.Literal sexpr
and symbol_expr : string -> Object.expr = fun s -> Object.Var s

and and_expr : Object.lobject -> Object.lobject -> Object.expr =
  fun cond_x cond_y -> Object.And (build_ast cond_x, build_ast cond_y)

and or_expr cond_x cond_y = Object.Or (build_ast cond_x, build_ast cond_y)
and quote_expr expr = Object.Literal (Quote expr)
and setq_expr name expr = Object.Defexpr (Object.Setq (name, build_ast expr))

and if_expr cond if_true if_false =
  If (build_ast cond, build_ast if_true, build_ast if_false)

and lambda_expr args body =
  (* Lambda body can be a single expression or a sequence of expressions.
     If body is a list with multiple expressions, we need to sequence them properly.
  *)
  let body_expr =
    if Object.is_list body then (
      let body_list = Object.pair_to_list body in
        match body_list with
        | [] ->
          Object.Literal Object.Nil
        | [ single_expr ] ->
          (* Single expression: parse it normally *)
          build_ast single_expr
        | _ :: _ ->
          (* Multiple expressions: sequence them *)
          let rec build_sequence = function
            | [] ->
              Object.Literal Object.Nil
            | [ last ] ->
              build_ast last
            | first' :: rest' ->
              let first_expr = build_ast first' in
              let rest_expr' = build_sequence rest' in
                Object.Let (Object.LET, [ "_", first_expr ], rest_expr')
          in
            build_sequence body_list
    ) else
      build_ast body
  in
    Lambda ("lambda", assert_unique_args args, body_expr)

and defun_expr fn_name args body =
  let lam = Object.Lambda (fn_name, assert_unique_args args, build_ast body) in
    Object.Defexpr
      (Object.Setq (fn_name, Let (Object.LETREC, [ fn_name, lam ], Object.Var fn_name)))

and apply_expr fn_expr args = Apply (build_ast fn_expr, build_ast args)

and let_expr s bindings expr =
  let make_binding = function
    | Object.Pair (Object.Symbol n, Pair (expr, Object.Nil)) ->
      n, build_ast expr
    | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(let bindings expr)"))
  in
  let bindings = List.map ~f:make_binding (Object.pair_to_list bindings) in
  let () = assert_unique (List.map ~f:fst bindings) in
  (* Let body can be a single expression or a sequence of expressions *)
  let body_expr =
    if Object.is_list expr then (
      let body_list = Object.pair_to_list expr in
        match body_list with
        | [] ->
          Object.Literal Object.Nil
        | [ single_expr ] ->
          build_ast single_expr
        | first :: rest -> (
          (* Multiple expressions: check if first is a define *)
          match first with
          | Object.Pair _ when Object.is_list first -> (
            match Object.pair_to_list first with
            | [ Object.Symbol "define"; Object.Symbol name; expr_val ] ->
              (* Define followed by more expressions: sequence them *)
              let define_expr = Object.Defexpr (Object.Setq (name, build_ast expr_val)) in
              let rest_expr =
                match rest with
                | [ last ] ->
                  build_ast last
                | _ ->
                  let rec build_sequence = function
                    | [] ->
                      Object.Literal Object.Nil
                    | [ last ] ->
                      build_ast last
                    | first' :: rest' ->
                      let first_expr = build_ast first' in
                      let rest_expr' = build_sequence rest' in
                        Object.Let (Object.LET, [ "temp", first_expr ], rest_expr')
                  in
                    build_sequence rest
              in
                Object.Let (Object.LET, [ "temp", define_expr ], rest_expr)
            | _ ->
              (* First element is not a define: treat entire body as single expression *)
              build_ast expr)
          | _ ->
            (* First element is not a list: treat entire body as single expression *)
            build_ast expr)
    ) else
      build_ast expr
  in
    Object.Let (to_kind s, bindings, body_expr)

and call_expr fn_expr args = Call (build_ast fn_expr, List.map ~f:build_ast args)

and cond_to_if = function
  | [] ->
    Object.Literal (Object.Symbol "error")
  | Object.Pair (cond, Object.Pair (res, Object.Nil)) :: condpairs ->
    If (build_ast cond, build_ast res, cond_to_if condpairs)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(cond conditions)"))

and module_expr name exports body_exprs =
  let extract_symbol = function
    | Object.Symbol s ->
      s
    | _ ->
      raise
        (Errors.Parse_error_exn (Errors.Type_error "(module name (export ...) body ...)"))
  in
  let export_list =
    match Object.pair_to_list exports with
    | Object.Symbol "export" :: symbols ->
      (* Skip the 'export' keyword and extract the rest *)
      List.map ~f:extract_symbol symbols
    | symbols ->
      (* No 'export' keyword, treat all as export symbols *)
      List.map ~f:extract_symbol symbols
  in
  (* body_exprs is now already an OCaml list of lobjects *)
  let body_ast_list = List.map ~f:build_ast body_exprs in
    Object.ModuleDef (name, export_list, body_ast_list)

and import_expr import_args =
  (* import_args is now an OCaml list of lobjects *)
  match import_args with
  | [ Object.Symbol module_name ] ->
    (* (import module-name) - import all *)
    Object.Import (Object.ImportAll module_name)
  | [ Object.Symbol module_name; Object.Symbol ":as"; Object.Symbol alias ] ->
    (* (import module-name :as alias) - import with alias *)
    Object.Import (Object.ImportAs (module_name, alias))
  | Object.Symbol module_name :: symbols ->
    (* (import module-name symbol1 symbol2 ...) - selective import *)
    let export_names =
      List.map symbols ~f:(function
        | Object.Symbol s ->
          s
        | _ ->
          raise
            (Errors.Parse_error_exn (Errors.Type_error "(import module-name symbol ...)")))
    in
      Object.Import (Object.ImportSelective (module_name, export_names))
  | _ ->
    raise
      (Errors.Parse_error_exn
         (Errors.Type_error "(import module-name [symbol ...] | :as alias)"))
;;

let rec string_expr =
  let spacesep_exp es = Mlisp_utils.String.spacesep (List.map ~f:string_expr es) in
  let string_of_binding (n, e) = [%string "(%{n} %{string_expr e})"] in
    function
    | Object.Literal e ->
      Object.string_object e
    | Object.Var n ->
      n
    | Object.If (c, t, f) ->
      [%string "(if %{string_expr c} %{string_expr t} %{string_expr f})"]
    | Object.And (c0, c1) ->
      [%string "(and %{string_expr c0} %{string_expr c1})"]
    | Object.Or (c0, c1) ->
      [%string "(or %{string_expr c0} %{string_expr c1})"]
    | Object.Apply (f, e) ->
      [%string "(apply %{string_expr f} %{string_expr e})"]
    | Object.Call (f, es) ->
      if List.length es = 0 then
        [%string "(%{string_expr f}%{spacesep_exp es})"]
      else
        [%string "(%{string_expr f} %{spacesep_exp es})"]
    | Object.Lambda (_, args, body) ->
      [%string "(lambda (%{Mlisp_utils.String.spacesep args}) %{string_expr body})"]
    | Object.Defexpr (Object.Setq (n, e)) ->
      [%string "(:= %{n} %{string_expr e})"]
    | Object.Defexpr (Object.Defun (n, ns, e)) ->
      [%string "(defun %{n} (%{Mlisp_utils.String.spacesep ns}) %{string_expr e})"]
    | Object.Defexpr (Object.Expr e) ->
      string_expr e
    | Object.Let (kind, bs, e) ->
      let str =
        match kind with
        | LET ->
          "let"
        | LETSTAR ->
          "let*"
        | LETREC ->
          "letrec"
      in
      let bindings = Mlisp_utils.String.spacesep (List.map ~f:string_of_binding bs) in
        [%string "(%{str} (%{bindings}) %{string_expr e})"]
    | Object.ModuleDef (name, exports, body_exprs) ->
      let exports_str = Mlisp_utils.String.spacesep exports in
      let body_str = Mlisp_utils.String.spacesep (List.map ~f:string_expr body_exprs) in
        [%string "(module %{name} (%{exports_str}) %{body_str})"]
    | Object.Import import_spec ->
      let import_str =
        match import_spec with
        | Object.ImportAll name ->
          [%string "(import %{name})"]
        | Object.ImportSelective (name, symbols) ->
          let symbols_str = Mlisp_utils.String.spacesep symbols in
            [%string "(import %{name} %{symbols_str})"]
        | Object.ImportAs (name, alias) ->
          [%string "(import %{name} :as %{alias})"]
      in
        import_str
;;
