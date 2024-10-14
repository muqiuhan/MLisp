(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Core

type 'a stream =
  { mutable line_num : int;
    mutable column : int;
    mutable chars : char list;
    stream : 'a Stream.t;
    repl_mode : bool;
    file_name : string
  }

type 'a t = 'a stream

let make_stream (type a) : ?file_name:string -> bool -> a Stream.t -> a stream =
  fun ?(file_name = "stdin") is_stdin stream ->
  { chars = []; line_num = 1; repl_mode = is_stdin; stream; file_name; column = 0 }
;;

let make_stringstream : string -> char stream = fun s -> make_stream false @@ Stream.of_string s

let make_filestream : ?file_name:string -> In_channel.t -> char stream =
  fun ?(file_name = "stdin") f -> make_stream ~file_name (phys_equal f In_channel.stdin) @@ Stream.of_channel f
;;
