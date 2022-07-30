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

open Mlisp.Stream
open Mlisp.Eval
open Mlisp.Environment
open Mlisp.Ast
open Mlisp.Types.Stream

let get_input_channel () =
  try open_in Sys.argv.(1) with
  | Invalid_argument _ -> stdin
;;

let rec repl a_stream env =
  if a_stream.chan = stdin
  then (
    print_string "> ";
    flush stdout);
  let ast = build_ast (read_sexpr a_stream) in
  let result, env' = eval ast env in
  if a_stream.chan = stdin then print_endline (string_object result);
  repl a_stream env'
;;

let () =
  let input_channel = get_input_channel () in
  let a_stream = { chrs = []; line_num = 1; chan = input_channel } in
  try repl a_stream basis with
  | End_of_file -> if input_channel <> stdin then close_in input_channel
;;
