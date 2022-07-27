(****************************************************************************)
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

type stream = {
  mutable line_num : int;
  mutable chrs : char list;
  chan : in_channel;
}

type t = stream

exception Syntax_error_exn of string

(** Read in a character *)
let read_char a_stream =
  match a_stream.chrs with
  | [] ->
      let a_char = input_char a_stream.chan in
      if a_char = '\n' then
        let _ = a_stream.line_num <- a_stream.line_num + 1 in
        a_char
      else a_char
  | a_char :: rest ->
      let _ = a_stream.chrs <- rest in
      a_char

(** Use for backtracking *)
let unread_char a_stream a_char = a_stream.chrs <- a_char :: a_stream.chrs

(** This will read whitespace characters and ignore then until it hits a non-whitespace character. *)
let rec eat_whitespace a_stream =
  let is_whitespace a_char =
    match a_char with ' ' | '\t' | '\n' -> true | _ -> false
  in
  let a_char = read_char a_stream in
  if is_whitespace a_char then eat_whitespace a_stream
  else unread_char a_stream a_char

(** Read in a whole number *)
let rec read_sexp a_stream =
  let is_digit a_char =
    let code = Char.code a_char in
    code >= Char.code '0' && code <= Char.code '9'
  in
  let rec read_fixnum acc =
    let num_char = read_char a_stream in
    if is_digit num_char then
      num_char |> Char.escaped |> ( ^ ) acc |> read_fixnum
    else
      let _ = unread_char a_stream num_char in
      Object.Fixnum (int_of_string acc)
  in
  let _ = eat_whitespace a_stream in
  let a_char = read_char a_stream in
  if is_digit a_char then a_char |> Char.escaped |> read_fixnum
  else raise (Syntax_error_exn ("Unexcepted character '" ^ Char.escaped a_char))
