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
      | [ Object.Fixnum a; Object.Fixnum b ] -> Object.Fixnum (operator a b)
      | _ ->
        raise
          (Errors.Parse_error_exn
             (Errors.Type_error [%string "(%{name} int int)"])) )
  ;;
end

module Compare = struct
  let generate name operator =
    ( name
    , function
      | [ Object.Fixnum a; Object.Fixnum b ] -> Object.Boolean (operator a b)
      | _ ->
        raise
          (Errors.Parse_error_exn
             (Errors.Type_error [%string "(%{name} int int)"])) )
  ;;
end

let basis =
  let open Core in
  [ Operator.generate "+" ( + )
  ; Operator.generate "-" ( - )
  ; Operator.generate "*" ( * )
  ; Operator.generate "/" ( / )
  ; Operator.generate "&&&" ( land )
  ; Operator.generate "|||" ( lor )
  ; Operator.generate "^^^" ( lxor )
  ; Operator.generate ">>>" ( lsl )
  ; Operator.generate "<<<" ( lsr )
  ; Operator.generate "%%%" ( mod )
  ; Compare.generate "int=" ( = )
  ; Compare.generate "int<" ( < )
  ; Compare.generate "int>" ( > )
  ; Compare.generate "int>=" ( >= )
  ; Compare.generate "int<=" ( <= )
  ]
;;
