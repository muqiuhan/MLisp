(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_utils
open Mlisp_repl
open Mlisp_stdlib
open Mlisp_version

let batch_mode = ref false

let get_input_channel () =
  let argc = Array.length Sys.argv in
  if argc > 1 then (
    let rec find_file i =
      if i >= argc then stdin
      else if Sys.argv.(i) = "--batch" then find_file (i + 1)
      else open_in Sys.argv.(i)
    in
    find_file 1
  ) else
    stdin
;;

let () =
  Array.iter (fun arg -> if arg = "--batch" then batch_mode := true) Sys.argv;
  let input_channel = get_input_channel () in
  let is_stdin = Core.phys_equal input_channel stdin in
  let stream =
    if is_stdin && not !batch_mode then (
      print_endline (Format.sprintf "o- %s\n" (Version.version_string ()));
      Stream_wrapper.make_filestream input_channel
    ) else if is_stdin && !batch_mode then (
      Stream_wrapper.make_filestream input_channel
    ) else (
      print_endline (Format.sprintf "o- Running %s ..." Sys.argv.(Array.length Sys.argv - 1));
      Stream_wrapper.make_filestream input_channel ~file_name:Sys.argv.(Array.length Sys.argv - 1)
    )
  in
  let has_error = ref false in
    (try Repl.repl stream Stdlib_loader.stdlib_core ~batch_mode:!batch_mode ~has_error with
     | e ->
       if input_channel <> stdin then close_in input_channel;
       raise e);
    if input_channel <> stdin then close_in input_channel;
    if !has_error then exit 1
;;
