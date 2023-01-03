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

type 'a stream =
  { mutable line_num : int
  ; mutable chrs : char list
  ; mutable column_number : int
  ; stm : 'a Stream.t
  ; stdin : bool
  ; file_name : string
  }

type 'a t = 'a stream

let make_stream ?(file_name = "stdin") is_stdin stm =
  { chrs = []; line_num = 1; stdin = is_stdin; stm; file_name; column_number = 0 }
;;

let make_stringstream s = make_stream false @@ Stream.of_string s

let make_filestream ?(file_name = "stdin") f =
  make_stream ~file_name (f = stdin) @@ Stream.of_channel f
;;
