(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Core
open Diagnose.Diagnose

type error_info =
  { file_name : string
  ; line_number : int
  ; column_number : int
  ; message : string
  ; help : string
  }

type t = error_info

(* Configure diagnose modules *)
module AnsiStyle = ConsoleAnsiStyle
module Doc = MakeAnnotatedDoc (AnsiStyle)
module Themes = MakeThemes (AnsiStyle)

module Report =
  MakeReport (AnsiStyle) (Doc)
    (struct
      let style = Themes.default_style
    end)

let rec repl_error : error_info -> unit =
  fun { file_name; line_number; column_number; message; help } ->
  let readonly_file_map = FilenameMap.empty in
  let report : string Report.t =
    { code = None
    ; message = help
    ; markers =
        [ ( { file = Some file_name
            ; begin_line = line_number
            ; end_line = line_number
            ; begin_col = 0 (* TODO: use column_number *)
            ; end_col = column_number + 1
            }
          , This message )
        ]
    ; blurbs = [ (* Hint help *) ]
    ; is_error = true
    }
  in
    print_endline
      (Report.pretty_report ~readonly_file_map ~with_unicode:true ~tab_size:4 report)

and file_error : error_info -> unit =
  fun ({ file_name; line_number; column_number; message; help } as err_info) ->
  try
    let source_lines = In_channel.read_lines file_name in
    let line_value = List.nth_exn source_lines (line_number - 1) in
    let get_end_col line start_col =
      let len = String.length line in
      let start_idx = start_col - 1 in
        if start_idx < 0 || start_idx >= len then
          start_col + 1
        else (
          let rec find_end i =
            if i >= len then
              len
            else (
              match String.get line i with
              | ' '
              | '\t'
              | '\n'
              | '\r'
              | '('
              | ')' ->
                i
              | _ ->
                find_end (i + 1)
            )
          in
          let end_idx = find_end start_idx in
            if end_idx = start_idx then
              start_idx + 2
            else
              end_idx + 1
        )
    in
    let end_col = get_end_col line_value column_number in
    let readonly_file_map =
      FilenameMap.singleton (Some file_name) (Array.of_list source_lines)
    in
    let report : string Report.t =
      { code = None
      ; message = help
      ; markers =
          [ ( { file = Some file_name
              ; begin_line = line_number
              ; end_line = line_number
              ; begin_col = 0 (* TODO: use column_number *)
              ; end_col
              }
            , This message )
          ]
      ; blurbs = [ (* Hint help *) ]
      ; is_error = true
      }
    in
      print_endline
        (Report.pretty_report ~readonly_file_map ~with_unicode:true ~tab_size:4 report)
  with
  | _ ->
    repl_error err_info
;;
