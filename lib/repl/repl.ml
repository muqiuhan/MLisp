(****************************************************************************)
(* MLisp                                                                    *)
(* Copyright (C) 2022 Muqiu Han                                             *)
(*                                                                          *)
(* This program is free software: you can redistribute it and/or modify     *)
(* it under the terms of the GNU Affero General Public License as published *)
(* by the Free Software Foundation, either version 3 of the License, or     *)
(* (at your option) any later version.                                      *)
(*                                                                          *)
(* This program is distributed in the hope that it will be useful,          *)
(* but WITHOUT ANY WARRANTY; without even the implied warranty of           *)
(* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            *)
(* GNU Affero General Public License for more details.                      *)
(*                                                                          *)
(* You should have received a copy of the GNU Affero General Public License *)
(* along with this program.  If not, see <https://www.gnu.org/licenses/>.   *)
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

let print_result result =
  Printf.printf "- : %s = %s\n\n"
    (Object.object_type result)
    (Object.string_object result);
  flush_all ()

let rec repl stream env =
  try
    if stream.stdin then print_prompt ();
    let ast = Ast.build_ast (Lexer.read_sexpr stream) in
    let result, env' = Eval.eval ast env in
    if stream.stdin then print_result result;
    stream.line_num <- 0;
    repl stream env'
  with
  | Stream.Failure -> if stream.stdin then print_newline () else ()
  | Errors.Syntax_error_exn e ->
    Mlisp_print.Error.print_error stream (Errors.Syntax_error_exn e);
    if stream.stdin then repl stream env else ()
  | Errors.Parse_error_exn e ->
    Mlisp_print.Error.print_error stream (Errors.Parse_error_exn e);
    if stream.stdin then repl stream env else ()
  | Errors.Runtime_error_exn e ->
    Mlisp_print.Error.print_error stream (Errors.Runtime_error_exn e);
    if stream.stdin then repl stream env else ()
  | e -> raise e
