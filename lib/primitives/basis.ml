(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object

let basis =
  let newprim acc (name, func) =
    Object.bind (name, Object.Primitive (name, func), acc)
  in
    [ Num.basis; String.basis; Std.basis ]
    |> Core.List.concat
    |> Core.List.fold_left
         ~f:newprim
         ~init:[ "empty-symbol", ref (Some (Object.Symbol "")) ]
;;
