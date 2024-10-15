(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Core

let basis =
  let newprim acc (name, func) =
    Object.bind (name, Object.Primitive (name, func), acc)
  in
    List.fold_left
      ~f:newprim
      ~init:[ "empty-symbol", ref (Some (Object.Symbol "")) ]
      [ Num.generate "+" ( + )
      ; Num.generate "-" ( - )
      ; Num.generate "*" ( * )
      ; Num.generate "/" ( / )
      ; Num.generate "%%" ( mod )
      ; Cmp.generate "=" ( = )
      ; Cmp.generate "<" ( < )
      ; Cmp.generate ">" ( > )
      ; Cmp.generate ">=" ( >= )
      ; Cmp.generate "<=" ( <= )
      ; "@", Std.list
      ; "$", Std.pair
      ; "car", Std.car
      ; "cdr", Std.cdr
      ; "==", Std.eq
      ; "atom?", Std.atomp
      ; "symbol?", Std.symp
      ; "getchar", Std.getchar
      ; "print", Std.print
      ; "int->char", Std.int_to_char
      ; "symbol-concat", Std.cat
      ; ":>", Std.record_get
      ; "::", Std.record_create
      ]
;;
