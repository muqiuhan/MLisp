(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_error
open Mlisp_utils
open Core
open Diagnose.Diagnose

(* Configure diagnose modules for warnings *)
module AnsiStyle = ConsoleAnsiStyle
module Doc = MakeAnnotatedDoc (AnsiStyle)
module Themes = MakeThemes (AnsiStyle)

module WarningReport =
  MakeReport (AnsiStyle) (Doc)
    (struct
      let style = Themes.default_style
    end)

let print_error (stream : 'a Stream_wrapper.t) exn =
  let open Mlisp_error.Error in
  let open Mlisp_error.Help in
  let error_code = Mlisp_error.Codes.error_code exn in
  let data =
    { file_name = stream.file_name
    ; line_number = !(stream.line_num)
    ; column_number = !(stream.column)
    ; message = Message.message exn
    ; help = help exn
    ; error_code
    }
  in
    if stream.repl_mode then
      data |> repl_error ~source_lines:stream.recent_input |> ignore
    else
      data |> file_error |> ignore
;;

(** Print a warning using diagnose library for consistent formatting.

    Uses the same formatting system as errors but with is_error = false.
    Provides structured warning output with proper formatting.

    @param module_name Name of the module where warning occurs
    @param expr_str String representation of the expression
    @param message Warning message
    @param file_name Optional file name for location information
    @param line_number Optional line number for location information
    @param column_number Optional column number for location information
    @param source_lines Optional source code lines for context display *)
let print_module_warning
      ?file_name
      ?line_number
      ?column_number
      ?source_lines
      module_name
      expr_str
      message
  =
  let file_name = Option.value file_name ~default:"<module>" in
  let line_number = Option.value line_number ~default:1 in
  let column_number = Option.value column_number ~default:1 in
  (* Create a structured message: title + guidance (no duplicate of marker message) *)
  let short_title =
    [%string "Module '%{module_name}': Non-definition expression: %{expr_str}"]
  in
  let warning_msg =
    [%string
      "%{short_title}\n\n\
       Guidance:\n\
      \  - Module bodies should contain only definitions\n\
      \  - Use (:= name value) for variables\n\
      \  - Use (|= name (args) body) for functions\n\
      \  - Use (import module) or (module ...) for modules"]
  in
  (* Create a warning report with source code context if available *)
  let readonly_file_map =
    match source_lines with
    | Some lines when not (List.is_empty lines) ->
      FilenameMap.singleton (Some file_name) (Array.of_list lines)
    | _ ->
      FilenameMap.empty
  in
  let begin_col = max 1 column_number in
  let end_col = begin_col + 1 in
  (* Marker message: the actual warning text shown in source context *)
  let marker_msg = message in
  let report : string WarningReport.t =
    { code = Some "W001"
    ; message = warning_msg
    ; markers =
        [ ( { file = Some file_name
            ; begin_line = line_number
            ; end_line = line_number
            ; begin_col
            ; end_col
            }
          , This marker_msg )
        ]
    ; blurbs = []
    ; is_error = false
    }
  in
    Out_channel.output_string
      Out_channel.stderr
      (WarningReport.pretty_report
         ~readonly_file_map
         ~with_unicode:true
         ~tab_size:4
         report);
    Out_channel.newline Out_channel.stderr;
    Out_channel.flush Out_channel.stderr
;;
