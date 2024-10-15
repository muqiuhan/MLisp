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
