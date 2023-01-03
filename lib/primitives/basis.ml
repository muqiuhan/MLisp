(****************************************************************************)
(* MLisp                                                                    *)
(* Copyright (C) 2022 Muqiu Han                                             *)
(*                                                                          *)
(* This program is free software: you can redistribute it and/or modify     *)
(* it under the terms of the GNU Affero General Public License as published *)
(* by the Free Software Foundation, either version 3 of the License, or     *)
(* (at your option) any later version.                                      *)
(*                                                                          *)
(* This program is distributed in the hope that it will be useful,          *)
(* but WITHOUT ANY WARRANTY; without even the implied warranty of           *)
(* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            *)
(* GNU Affero General Public License for more details.                      *)
(*                                                                          *)
(* You should have received a copy of the GNU Affero General Public License *)
(* along with this program.  If not, see <https://www.gnu.org/licenses/>.   *)
(****************************************************************************)

open Mlisp_object

let basis =
  let newprim acc (name, func) = Object.bind (name, Object.Primitive (name, func), acc) in
  List.fold_left
    newprim
    [ "empty-symbol", ref (Some (Object.Symbol "")) ]
    [ Num.generate "+" ( + )
    ; Num.generate "-" ( - )
    ; Num.generate "*" ( * )
    ; Num.generate "/" ( / )
    ; Num.generate "mod" ( mod )
    ; Cmp.generate "=" ( = )
    ; Cmp.generate "<" ( < )
    ; Cmp.generate ">" ( > )
    ; Cmp.generate ">=" ( >= )
    ; Cmp.generate "<=" ( <= )
    ; "list", Core.list
    ; "pair", Core.pair
    ; "car", Core.car
    ; "cdr", Core.cdr
    ; "eq", Core.eq
    ; "atom?", Core.atomp
    ; "sym?", Core.symp
    ; "getchar", Core.getchar
    ; "print", Core.print
    ; "int->char", Core.int_to_char
    ; "cat", Core.cat
    ]
;;
