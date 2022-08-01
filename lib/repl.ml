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

let rec repl a_stream env =
  try
    if a_stream.stdin
    then (
      print_string "# ";
      flush stdout);
    let ast = Ast.build_ast (Reader.read_sexpr a_stream) in
    let result, env' = Eval.eval ast env in
    if a_stream.stdin then print_endline (Ast.string_object result);
    repl a_stream env'
  with
  | Stream.Failure -> ()
  | e -> raise e
;;
