(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

include Core.String

let spacesep ns = concat ~sep:" " ns

let read_lines filename =
  let lines = ref [] in
  let chan = open_in filename in
      try
        while true do
          lines := input_line chan :: !lines
        done;
        !lines
      with
      | End_of_file ->
        close_in chan;
        List.rev !lines
;;
