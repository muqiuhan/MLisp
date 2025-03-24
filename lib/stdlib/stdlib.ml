(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Mlisp_eval
open Mlisp_lexer
open Mlisp_ast
open Mlisp_utils
open Core

let eval env e =
  match e with
  | Object.Defexpr d -> Eval.eval_def d env
  | expr ->
    raise
      (Errors.Runtime_error_exn
         (Errors.Non_definition_in_stdlib (Mlisp_ast.Ast.string_expr expr)))
;;

let rec slurp stm env =
  try
    stm |> Lexer.read_sexpr |> Ast.build_ast |> eval env |> snd |> slurp stm
  with
  | Stream.Failure -> env
  | exn -> failwith (Mlisp_error.Message.message exn)
;;

let stdlib_core =
  print_endline
    (Format.sprintf
       "o- Loading standard core library (MLisp stdlib_core.v%s) ..."
       Stdlib_core._STDLIB_CORE_VERSION_);
  let stm = Stdlib_core._STDLIB_CORE_ |> Stream_wrapper.make_stringstream in
    slurp stm Mlisp_primitives.Basis.basis
;;
