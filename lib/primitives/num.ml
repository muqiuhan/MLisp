(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error

let generate name operator =
  ( name,
    function
    | [ Object.Fixnum a; Object.Fixnum b ] -> Object.Fixnum (operator a b)
    | _ -> raise (Errors.Parse_error_exn (Errors.Type_error ("(" ^ name ^ " int int)"))) )
;;
