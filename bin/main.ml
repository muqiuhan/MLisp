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

open Mlisp.Reader
open Mlisp.Eval
open Mlisp.Environment
open Mlisp.Ast
open Mlisp.Types.Reader
open Mlisp.Types.Object

let stdlib_path = "/usr/include/mlisp/stdlib.mlisp"

let get_input_channel () =
  try open_in Sys.argv.(1) with
  | Invalid_argument _ -> stdin
;;

let () =
  let rec repl a_stream env =
    if a_stream.stdin
    then (
      print_string "> ";
      flush stdout);
    let ast = build_ast (read_sexpr a_stream) in
    let result, env' = eval ast env in
    if a_stream.stdin then print_endline (string_object result);
    repl a_stream env'
  in
  let stdlib =
    let eval env e =
      match e with
      | Defexpr d -> eval_def d env
      | _ -> raise (Type_error_exn "Can only have definitions in stdlib")
    in
    let rec slurp stm env =
      try stm |> read_sexpr |> build_ast |> eval env |> snd |> slurp stm with
      | Stream.Failure -> env
    in
    let stm = make_filestream (open_in stdlib_path) in
    slurp stm basis
  in
  let input_channel = get_input_channel () in
  try repl (make_filestream input_channel) stdlib with
  | _ ->
    if input_channel = stdin
    then repl (make_filestream input_channel) stdlib
    else close_in input_channel
;;
