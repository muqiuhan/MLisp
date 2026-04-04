(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error

module Operator = struct
  let generate name operator =
    ( name
    , function
      | [ Object.String a; Object.String b ] ->
        Object.String (operator a b)
      | _ ->
        raise
          (Errors.Parse_error_exn (Errors.Type_error [%string "(%{name} string string)"]))
    )
  ;;
end

module Compare = struct
  let generate name operator =
    ( name
    , function
      | [ Object.String a; Object.String b ] ->
        Object.Boolean (operator a b)
      | _ ->
        raise
          (Errors.Parse_error_exn (Errors.Type_error [%string "(%{name} string string)"]))
    )
  ;;
end

let basis =
  let open Core in
  [ Operator.generate "@" String.( ^ ) ]
;;
