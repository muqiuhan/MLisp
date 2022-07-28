(****************************************************************************)
(* OCamLisp                                                                 *)
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

open Ocamlisp.Stream
open Ocamlisp.Eval
open Ocamlisp.Environment
open Ocamlisp.Ast

let rec repl a_stream env =
  print_string "> ";
  flush stdout;
  let ast = build_ast (read_sexpr a_stream) in
  let result, env' = eval ast env in
  let () = print_string (string_val result) in
  print_newline ();
  repl a_stream env'

let () =
  try repl { chrs = []; line_num = 1; chan = stdin } basis
  with End_of_file -> print_endline "Goodbye!"
