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

open Mlisp_error
open Mlisp_utils

let print_error (stream : 'a Stream_wrapper.t) exn =
  let open Mlisp_error.Error in
  let open Mlisp_error.Help in
  let data =
    { file_name = stream.file_name
    ; line_number = stream.line_num
    ; column_number = stream.column_number
    ; message = Message.message exn
    ; help = help exn
    }
  in
  if stream.stdin
  then data |> repl_error |> ignore |> flush_all
  else data |> file_error |> ignore |> flush_all
;;
