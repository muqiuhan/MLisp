(****************************************************************************)
(* OCamLisp                                                                 *)
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

open Types

let rec list = function
  | [] -> Object.Nil
  | car :: cdr -> Object.Pair (car, list cdr)

let plus = function
  | [ Object.Fixnum a; Object.Fixnum b ] -> Object.Fixnum (a + b)
  | _ -> raise (Object.Type_error_exn "(+ int int)")

let pair = function
  | [ a; b ] -> Object.Pair (a, b)
  | _ -> raise (Object.Type_error_exn "(pair a b)")

let car = function
  | [ Object.Pair (car, _) ] -> car
  | _ -> raise (Object.Type_error_exn "(car non-nil-pair)")

let cdr = function
  | [ Object.Pair (_, cdr) ] -> cdr
  | _ -> raise (Object.Type_error_exn "(cdr non-nil-pair)")

let atomp = function
  | [ Object.Pair (_, _) ] -> Object.Boolean false
  | [ _ ] -> Object.Boolean true
  | _ -> raise (Object.Type_error_exn "(atom? something)")

let eq = function
  | [ a; b ] -> Object.Boolean (a = b)
  | _ -> raise (Object.Type_error_exn "(eq a b)")

module Num = struct
  let generate name operator =
    ( name,
      function
      | [ Object.Fixnum a; Object.Fixnum b ] -> Object.Fixnum (operator a b)
      | _ -> raise (Object.Type_error_exn ("(" ^ name ^ " int int)")) )
end

module Cmp = struct
  let generate name operator =
    ( name,
      function
      | [ Object.Fixnum a; Object.Fixnum b ] -> Object.Boolean (operator a b)
      | _ -> raise (Object.Type_error_exn ("(" ^ name ^ " int int)")) )
end
