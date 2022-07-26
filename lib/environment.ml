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

open Types.Object
open Types.Eval

let rec lookup = function
  | n, [] -> raise (Runtime_error_exn (Not_found n))
  | n, (n', v) :: _ when n = n' ->
    (match !v with
    | Some v' -> v'
    | None -> raise (Runtime_error_exn (Unspecified_value n)))
  | n, (_, _) :: bs -> lookup (n, bs)
;;

let bind (name, value, sexpr) = (name, ref (Some value)) :: sexpr
let make_local _ = ref None
let bind_local (n, vor, e) = (n, vor) :: e
let bind_list ns vs env = 
  try
    List.fold_left2 (fun acc n v -> bind (n, v, acc)) env ns vs
  with Invalid_argument _ -> raise (Runtime_error_exn (Missing_argument ns))

let bind_local_list ns vs env =
  try
    List.fold_left2 (fun acc n v -> bind_local (n, v, acc)) env ns vs
  with Invalid_argument _ -> raise (Runtime_error_exn (Missing_argument ns))
;;

let basis =
  let newprim acc (name, func) = bind (name, Primitive (name, func), acc) in
  List.fold_left
    newprim
    [ "empty-symbol", ref (Some (Symbol "")) ]
    [ Primitives.Num.generate "+" ( + )
    ; Primitives.Num.generate "-" ( - )
    ; Primitives.Num.generate "*" ( * )
    ; Primitives.Num.generate "/" ( / )
    ; Primitives.Num.generate "mod" ( mod )
    ; Primitives.Cmp.generate "=" ( = )
    ; Primitives.Cmp.generate "<" ( < )
    ; Primitives.Cmp.generate ">" ( > )
    ; Primitives.Cmp.generate ">=" ( >= )
    ; Primitives.Cmp.generate "<=" ( <= )
    ; "list", Primitives.list
    ; "pair", Primitives.pair
    ; "car", Primitives.car
    ; "cdr", Primitives.cdr
    ; "eq", Primitives.eq
    ; "atom?", Primitives.atomp
    ; "sym?", Primitives.symp
    ; "getchar", Primitives.getchar
    ; "print", Primitives.print
    ; "int->char", Primitives.int_to_char
    ; "cat", Primitives.cat
    ]
;;

let rec env_to_val =
  let b_to_val (n, vor) =
    Pair
      ( Symbol n
      , match !vor with
        | None -> Symbol "unspecified"
        | Some v -> v )
  in
  function
  | [] -> Nil
  | b :: bs -> Pair (b_to_val b, env_to_val bs)
;;
