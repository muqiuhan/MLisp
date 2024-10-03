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

open Mlisp_utils

type error_info = {
  file_name : string;
  line_number : int;
  column_number : int;
  message : string;
  help : string;
}

type t = error_info

let repl_error {file_name; line_number; column_number; message; help} =
  Ocolor_format.printf
    "\n\
     @{<hi_white>|@} @{<hi_cyan>From : \"%s\" , Line: %d , Column: %d@}\n\
     @{<hi_white>|@} @{<hi_red>| Error: %s@}\n\
     @{<hi_white>|@} @{<hi_green>| Help : %s@}\n\n"
    file_name line_number column_number message help

let file_error {file_name; line_number; column_number; message; help} =
  let split_line {file_name; line_number; column_number; message; help}
      line_value =
    let char_num =
      List.fold_left
        (fun max prev ->
          if prev > max then
            prev
          else
            max)
        (String.length
           (string_of_int line_number ^ string_of_int column_number ^ file_name)
        + 31)
        [
          String.length message + 9;
          String.length help + 9;
          String.length line_value + 8;
        ]
    in
      "+" ^ String.make (char_num + 4) '-'
  in
  let line_value = List.nth (String.read_lines file_name) (line_number - 1) in
  let split_line =
    split_line {file_name; line_number; column_number; message; help} line_value
  in
  let tip_mark = "+" ^ String.make (String.length line_value + 5) '-' ^ "^" in
    Ocolor_format.printf
      "\n\
       @{<hi_white>%s@}\n\
       @{<hi_white>|@} @{<hi_cyan>From : \"%s\" , Line: %d , Column: %d@}\n\
       @{<hi_white>|@}------> @{<hi_white>%s@}\n\
       @{<hi_white>|@} @{<hi_red>%s@}\n\
       @{<hi_white>|@} @{<hi_red>| Error: %s@}\n\
       @{<hi_white>|@} @{<hi_green>| Help : %s@}\n\
       @{<hi_white>%s@}\n"
      split_line file_name line_number column_number line_value tip_mark message
      help split_line
