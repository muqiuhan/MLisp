(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Mlisp_utils

let rec assert_unique = function
  | []      ->
    ()
  | x :: xs ->
    if List.mem x xs
    then raise (Errors.Parse_error_exn (Unique_error x))
    else assert_unique xs
;;

let assert_unique_args args =
  let names =
    List.map
      (function
        | Object.Symbol s ->
          s
        | _               ->
          raise (Errors.Parse_error_exn (Type_error "(defun name (formals) body)")))
      (Object.pair_to_list args)
  in
  let () = assert_unique names in
    names
;;

let let_kinds = ["let", Object.LET; "let*", Object.LETSTAR; "letrec", Object.LETREC]
let valid_let s = List.mem_assoc s let_kinds
let to_kind s = List.assoc s let_kinds

let rec build_ast sexpr =
  match sexpr with
  | Object.Primitive _ | Object.Closure _ ->
    raise Errors.This_can't_happen_exn
  | Object.Fixnum _
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
    | [Object.Symbol "if"; cond; if_true; if_false] ->
      if_expr cond if_true if_false
    | Object.Symbol "cond" :: conditions ->
      cond_to_if conditions
    | [Object.Symbol "and"; cond_x; cond_y] ->
      and_expr cond_x cond_y
    | [Object.Symbol "or"; cond_x; cond_y] ->
      or_expr cond_x cond_y
    | [Object.Symbol "quote"; expr] ->
      quote_expr expr
    | [Object.Symbol "setq"; Object.Symbol name; expr] ->
      setq_expr name expr
    | [Object.Symbol "record"; Object.Symbol name; fields] ->
      record_expr name fields
    | [Object.Symbol "lambda"; args; body] when Object.is_list args ->
      lambda_expr args body
    | [Object.Symbol "apply"; fn_expr; args] ->
      apply_expr fn_expr args
    | [Object.Symbol "defun"; Object.Symbol fn_name; args; body] ->
      defun_expr fn_name args body
    | [Object.Symbol s; bindings; expr] when Object.is_list bindings && valid_let s ->
      let_expr s bindings expr
    | fn_expr :: args ->
      call_expr fn_expr args
    | [] ->
      raise (Errors.Parse_error_exn Poorly_formed_expression))
  | Pair _ ->
    Object.Literal sexpr

and literal_expr sexpr = Object.Literal sexpr
and symbol_expr s = Object.Var s
and and_expr cond_x cond_y = Object.And (build_ast cond_x, build_ast cond_y)
and or_expr cond_x cond_y = Object.Or (build_ast cond_x, build_ast cond_y)
and quote_expr expr = Object.Literal (Quote expr)
and setq_expr name expr = Object.Defexpr (Object.Setq (name, build_ast expr))

and if_expr cond if_true if_false =
  If (build_ast cond, build_ast if_true, build_ast if_false)

and record_expr name fields = Defexpr (Defrecord (name, assert_unique_args fields))
and lambda_expr args body = Lambda ("lambda", assert_unique_args args, build_ast body)

and defun_expr fn_name args body =
  let lam = Object.Lambda (fn_name, assert_unique_args args, build_ast body) in
    Object.Defexpr
      (Object.Setq (fn_name, Let (Object.LETREC, [fn_name, lam], Object.Var fn_name)))

and apply_expr fn_expr args = Apply (build_ast fn_expr, build_ast args)

and let_expr s bindings expr =
  let make_binding = function
    | Object.Pair (Object.Symbol n, Pair (expr, Object.Nil)) ->
      n, build_ast expr
    | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(let bindings expr)"))
  in
  let bindings = List.map make_binding (Object.pair_to_list bindings) in
  let () = assert_unique (List.map fst bindings) in
    Object.Let (to_kind s, bindings, build_ast expr)

and call_expr fn_expr args = Call (build_ast fn_expr, List.map build_ast args)

and cond_to_if = function
  | [] ->
    Object.Literal (Object.Symbol "error")
  | Object.Pair (cond, Object.Pair (res, Object.Nil)) :: condpairs ->
    If (build_ast cond, build_ast res, cond_to_if condpairs)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(cond conditions)"))
;;

let rec string_expr =
  let spacesep_exp es = String.spacesep (List.map string_expr es) in
  let string_of_binding (n, e) = "(" ^ n ^ " " ^ string_expr e ^ ")" in
    function
    | Object.Literal e ->
      Object.string_object e
    | Object.Var n ->
      n
    | Object.If (c, t, f) ->
      "(if " ^ string_expr c ^ " " ^ string_expr t ^ " " ^ string_expr f ^ ")"
    | Object.And (c0, c1) ->
      "(and " ^ string_expr c0 ^ " " ^ string_expr c1 ^ ")"
    | Object.Or (c0, c1) ->
      "(or " ^ string_expr c0 ^ " " ^ string_expr c1 ^ ")"
    | Object.Apply (f, e) ->
      "(apply " ^ string_expr f ^ " " ^ string_expr e ^ ")"
    | Object.Call (f, es) ->
      if List.length es == 0
      then "(" ^ string_expr f ^ spacesep_exp es ^ ")"
      else "(" ^ string_expr f ^ " " ^ spacesep_exp es ^ ")"
    | Object.Lambda (_, args, body) ->
      "(lambda (" ^ String.spacesep args ^ ") " ^ string_expr body ^ ")"
    | Object.Defexpr (Object.Setq (n, e)) ->
      "(setq " ^ n ^ " " ^ string_expr e ^ ")"
    | Object.Defexpr (Object.Defun (n, ns, e)) ->
      "(defun " ^ n ^ "(" ^ String.spacesep ns ^ ") " ^ string_expr e ^ ")"
    | Object.Defexpr (Object.Expr e) ->
      string_expr e
    | Object.Defexpr (Object.Defrecord (name, field_list)) ->
      "(record " ^ name ^ String.spacesep field_list ^ ")"
    | Object.Let (kind, bs, e) ->
      let str = match kind with LET -> "let" | LETSTAR -> "let*" | LETREC -> "letrec" in
      let bindings = String.spacesep (List.map string_of_binding bs) in
        "(" ^ str ^ " (" ^ bindings ^ ") " ^ string_expr e ^ ")"
;;
