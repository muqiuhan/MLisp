(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_utils
open Mlisp_repl
open Mlisp_stdlib

let get_input_channel () = try open_in Sys.argv.(1) with Invalid_argument _ -> stdin

let () =
  let input_channel = get_input_channel () in
  let stream =
    if input_channel = stdin then (
      print_endline "o- MLisp v0.2.1 (main, 2024-10-14 9:41 PM) [OCaml 5.2.0]\n";
      Stream_wrapper.make_filestream input_channel
    ) else
      Stream_wrapper.make_filestream input_channel ~file_name:Sys.argv.(1)
in
      try Repl.repl stream Stdlib.stdlib with
      | e ->
          if input_channel <> stdin then
            close_in input_channel
          else
            print_endline "Goodbye!";
          raise e
;;
