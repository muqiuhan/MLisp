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

module Environment = struct
  type 'a env = (string * 'a option ref) list
end

module Object = struct
  exception This_can't_happen_exn
  exception Type_error_exn of string

  type lobject =
    | Fixnum of int
    | Boolean of bool
    | Symbol of string
    | Nil
    | Pair of lobject * lobject
    | Primitive of string * (lobject list -> lobject)
    | Quote of value
    | Closure of name list * expr * value Environment.env

  and value = lobject
  and name = string

  and let_kind =
    | LET
    | LETSTAR
    | LETREC

  and expr =
    | Literal of value
    | Var of name
    | If of expr * expr * expr
    | And of expr * expr
    | Or of expr * expr
    | Apply of expr * expr
    | Call of expr * expr list
    | Defexpr of def
    | Lambda of name list * expr
    | Let of let_kind * (name * expr) list * expr

  and def =
    | Setq of name * expr
    | Defun of name * name list * expr
    | Expr of expr
end

module Ast = struct
  exception Parse_error_exn of string
  exception Unique_error_exn of string
end

module Stream = struct
  type stream =
    { mutable line_num : int
    ; mutable chrs : char list
    ; chan : in_channel
    }
end
