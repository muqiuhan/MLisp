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
  let initial_env = Object.create_env () in
    Object.bind ("empty-symbol", Object.Symbol "", initial_env) |> ignore;
    [ Num.basis; String.basis; Std.basis ]
    |> Core.List.concat
    |> Core.List.fold_left ~f:newprim ~init:initial_env
;;
