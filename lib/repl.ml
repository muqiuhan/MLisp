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

open Types.Reader
open Types.Ast
open Types.Eval
open Types.Repl

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

let rec repl a_stream env =
  try
    if a_stream.stdin then print_prompt ();
    let ast = Ast.build_ast (Reader.read_sexpr a_stream) in
    let result, env' = Eval.eval ast env in
    if a_stream.stdin then print_result result;
    a_stream.line_num <- 0;
    repl a_stream env'
  with
  | Stream.Failure -> if a_stream.stdin then print_newline () else ()
  | Syntax_error_exn e ->
    Error.print_error a_stream (Syntax_error_exn e);
    if a_stream.stdin then repl a_stream env else ()
  | Parse_error_exn e ->
    Error.print_error a_stream (Parse_error_exn e);
    if a_stream.stdin then repl a_stream env else ()
  | Runtime_error_exn e ->
    Error.print_error a_stream (Runtime_error_exn e);
    if a_stream.stdin then repl a_stream env else ()
  | e -> raise e
;;
