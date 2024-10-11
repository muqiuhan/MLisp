(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

type 'a stream =
  { mutable line_num : int;
    mutable chrs : char list;
    mutable column_number : int;
    stm : 'a Stream.t;
    stdin : bool;
    file_name : string }

type 'a t = 'a stream

let make_stream ?(file_name = "stdin") is_stdin stm =
  {chrs = []; line_num = 1; stdin = is_stdin; stm; file_name; column_number = 0}
;;

let make_stringstream s = make_stream false @@ Stream.of_string s

let make_filestream ?(file_name = "stdin") f =
  make_stream ~file_name (f = stdin) @@ Stream.of_channel f
;;
