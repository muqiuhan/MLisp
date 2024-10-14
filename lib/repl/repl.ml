(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_ast
open Mlisp_lexer
open Mlisp_eval
open Mlisp_error
open Mlisp_utils.Stream_wrapper
open Mlisp_vars.Repl

let print_prompt () =
  Printf.printf "%s " prompt_tip;
  flush_all ()
;;

let print_result result =
  Printf.printf
    "- : %s = %s\n\n"
    (Object.object_type result)
    (Object.string_object result);
  flush_all ()
;;

let rec repl stream env =
  try
    if stream.repl_mode then print_prompt ();
    let ast = Ast.build_ast (Lexer.read_sexpr stream) in
    let result, env' = Eval.eval ast env in
        if stream.repl_mode then print_result result;
        stream.line_num <- 0;
        repl stream env'
  with
  | Stream.Failure ->
      if stream.repl_mode then
        print_newline ()
      else
        ()
  | Errors.Syntax_error_exn e ->
      Mlisp_print.Error.print_error stream (Errors.Syntax_error_exn e);
      if stream.repl_mode then
        repl stream env
      else
        ()
  | Errors.Parse_error_exn e ->
      Mlisp_print.Error.print_error stream (Errors.Parse_error_exn e);
      if stream.repl_mode then
        repl stream env
      else
        ()
  | Errors.Runtime_error_exn e ->
      Mlisp_print.Error.print_error stream (Errors.Runtime_error_exn e);
      if stream.repl_mode then
        repl stream env
      else
        ()
  | e ->
      raise e
;;
