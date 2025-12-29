(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_utils
open Mlisp_repl
open Mlisp_stdlib
open Mlisp_version

let get_input_channel () =
  try open_in Sys.argv.(1) with
  | Invalid_argument _ ->
    stdin
;;

let () =
  let input_channel = get_input_channel () in
  let stream =
    if input_channel = stdin then (
      print_endline (Format.sprintf "o- %s\n" (Version.version_string ()));
      Stream_wrapper.make_filestream input_channel
    ) else (
      print_endline (Format.sprintf "o- Running %s ..." Sys.argv.(1));
      Stream_wrapper.make_filestream input_channel ~file_name:Sys.argv.(1)
    )
  in
  let has_error = ref false in
    (try Repl.repl stream Stdlib.stdlib_core ~has_error with
     | e ->
       if input_channel <> stdin then close_in input_channel;
       raise e);
    if input_channel <> stdin then close_in input_channel;
    if !has_error then exit 1
;;
