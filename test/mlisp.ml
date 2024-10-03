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

let exec_path = "../bin/main.exe"
let test_path = "../../../test/"

let is_mlisp_file file_name =
  match String.split_on_char '.' file_name with
  | _ :: ["mlisp"] -> true
  | _ -> false

let test_mlisp_file file_name =
  Sys.command (exec_path ^ " " ^ test_path ^ file_name) |> ignore

let test_files =
  test_path
  |> Sys.readdir
  |> Array.iter (fun file_name ->
         if is_mlisp_file file_name then (
           flush_all ();
           Printf.printf "Test %s ..." file_name;
           test_mlisp_file file_name;
           print_endline "done!"
         ) else
           ())
