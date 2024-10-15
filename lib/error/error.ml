(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Core

type error_info =
  { file_name : string
  ; line_number : int
  ; column_number : int
  ; message : string
  ; help : string
  }

type t = error_info

let repl_error : error_info -> unit =
  fun { file_name; line_number; column_number; message; help } ->
  Ocolor_format.printf
    "\n\
     @{<hi_white>|@} @{<hi_cyan>From : \"%s\" , Line: %d , Column: %d@}\n\
     @{<hi_white>|@} @{<hi_red>| Error: %s@}\n\
     @{<hi_white>|@} @{<hi_green>| Help : %s@}\n\n"
    file_name
    line_number
    column_number
    message
    help
;;

let file_error { file_name; line_number; column_number; message; help } =
  let split_line
    { file_name; line_number; column_number; message; help }
    line_value
    =
    let char_num =
      [ String.length message + 9
      ; String.length help + 9
      ; String.length line_value + 8
      ]
      |> List.fold_left
           ~f:(fun _max prev ->
             if Int.(prev > _max) then
               prev
             else
               _max)
           ~init:
             (String.length
                [%string
                  "%{string_of_int line_number}%{string_of_int \
                   column_number}%{file_name}"]
              + 31)
    in
      [%string "+%{String.make (char_num + 4) '-'}"]
  in
  let line_value =
    List.nth_exn (In_channel.read_lines file_name) (line_number - 1)
  in
  let split_line =
    split_line
      { file_name; line_number; column_number; message; help }
      line_value
  in
  let tip_mark =
    [%string "+%{String.make (String.length line_value + 5) '-'}^"]
  in
    Ocolor_format.printf
      "\n\
       @{<hi_white>%s@}\n\
       @{<hi_white>|@} @{<hi_cyan>From : \"%s\" , Line: %d , Column: %d@}\n\
       @{<hi_white>|@}------> @{<hi_white>%s@}\n\
       @{<hi_white>|@} @{<hi_red>%s@}\n\
       @{<hi_white>|@} @{<hi_red>| Error: %s@}\n\
       @{<hi_white>|@} @{<hi_green>| Help : %s@}\n\
       @{<hi_white>%s@}\n"
      split_line
      file_name
      line_number
      column_number
      line_value
      tip_mark
      message
      help
      split_line
;;
