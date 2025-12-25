(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_error
open Mlisp_utils
open Core

let print_error (stream : 'a Stream_wrapper.t) exn =
  let open Mlisp_error.Error in
  let open Mlisp_error.Help in
  let data =
    { file_name = stream.file_name
    ; line_number = !(stream.line_num)
    ; column_number = !(stream.column)
    ; message = Message.message exn
    ; help = help exn
    }
  in
    if stream.repl_mode then
      data |> repl_error |> ignore
    else
      data |> file_error |> ignore;
    Out_channel.flush Out_channel.stdout
;;

(** Print a warning without stream information.

    Used when stream information is not available (e.g., during module evaluation).
    Prints a simple warning message to stderr with ANSI color codes for visibility.

    @param module_name Name of the module where warning occurs
    @param expr_str String representation of the expression
    @param message Warning message *)
let print_module_warning module_name expr_str message =
  let warning_msg =
    [%string
      "\027[33m[warning]\027[0m Module '%{module_name}': Non-definition expression in module body: %{expr_str}. %{message}"]
  in
    (* Always output to stderr, even if stdout is redirected *)
    Out_channel.output_string Out_channel.stderr warning_msg;
    Out_channel.newline Out_channel.stderr;
    Out_channel.flush Out_channel.stderr
;;
