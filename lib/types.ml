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

module Environment = struct
  type 'a env = (string * 'a option ref) list
end

module Object = struct
  exception This_can't_happen_exn

  type lobject =
    | Fixnum of int
    | Boolean of bool
    | Symbol of string
    | String of string
    | Nil
    | Pair of lobject * lobject
    | Record of name * lobject list
    | Primitive of string * (lobject list -> lobject)
    | Quote of value
    | Closure of name list * expr * value Environment.env

  and value = lobject
  and name = string
  and let_kind = LET | LETSTAR | LETREC

  and expr =
    | Literal of value
    | Var of name
    | If of expr * expr * expr
    | And of expr * expr
    | Or of expr * expr
    | Apply of expr * expr
    | Call of expr * expr list
    | Defexpr of def
    | Consexpr of cons
    | Lambda of name list * expr
    | Let of let_kind * (name * expr) list * expr

  and def =
    | Setq of name * expr
    | Defun of name * name list * expr
    | Defrecord of name * name list
    | Expr of expr

  and cons = Consrecord of name * name list
end

module Ast = struct
  exception Undefined_symbol_exn of string

  type parse_error =
    | Unique_error of string
    | Type_error of string
    | Poorly_formed_expression

  exception Parse_error_exn of parse_error
end

module Reader = struct
  type syntax_error =
    | Invalid_boolean_literal of string
    | Unexcepted_character of string

  exception Syntax_error_exn of syntax_error

  type 'a stream = {
    mutable line_num : int;
    mutable chrs : char list;
    mutable column_number : int;
    stm : 'a Stream.t;
    stdin : bool;
    file_name : string;
  }
end

module Eval = struct
  type runtime_error =
    | Not_found of string
    | Unspecified_value of string
    | Missing_argument of string list

  exception Runtime_error_exn of runtime_error
end

module Error = struct
  type error_info = {
    file_name : string;
    line_number : int;
    column_number : int;
    message : string;
    help : string;
  }
end

module Repl = struct
  let prompt_tip = "mlisp>"
  let prompt_tip_length = String.length prompt_tip + 1
end
