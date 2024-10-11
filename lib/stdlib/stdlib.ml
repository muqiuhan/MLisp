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
open Mlisp_primitives

let eval env e =
  match e with
  | Object.Defexpr d -> Eval.eval_def d env
  | _ ->
    raise
      (Errors.Parse_error_exn (Errors.Type_error "Can only have definitions in stdlib"))
;;

let rec slurp stm env =
  try stm |> Lexer.read_sexpr |> Ast.build_ast |> eval env |> snd |> slurp stm with
  | Stream.Failure -> env
;;

let stdlib =
  let stm = Stream_wrapper.make_stringstream Stdlib_string.stdlib_string in
    slurp stm Basis.basis
;;
