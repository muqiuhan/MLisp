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

type stream =
  { mutable line_num : int
  ; mutable chrs : char list
  ; chan : in_channel
  }

type t = stream

exception Syntax_error_exn of string

(** Read in a character *)
let read_char a_stream =
  match a_stream.chrs with
  | [] ->
    let a_char = input_char a_stream.chan in
    if a_char = '\n'
    then (
      let _ = a_stream.line_num <- a_stream.line_num + 1 in
      a_char)
    else a_char
  | a_char :: rest ->
    let _ = a_stream.chrs <- rest in
    a_char
;;

(** Use for backtracking *)
let unread_char a_stream a_char = a_stream.chrs <- a_char :: a_stream.chrs

let is_whitespace a_char =
  match a_char with
  | ' ' | '\t' | '\n' -> true
  | _ -> false
;;

(** This will read whitespace characters and ignore then until it hits a non-whitespace character. *)
let rec eat_whitespace a_stream =
  let a_char = read_char a_stream in
  if is_whitespace a_char then eat_whitespace a_stream else unread_char a_stream a_char
;;

let string_of_char a_char = String.make 1 a_char

let is_digit a_char =
  let code = Char.code a_char in
  code >= Char.code '0' && code <= Char.code '9'
;;

let rec read_fixnum a_stream acc =
  let rec loop acc =
    let num_char = read_char a_stream in
    if is_digit num_char
    then num_char |> Char.escaped |> ( ^ ) acc |> loop
    else (
      let _ = unread_char a_stream num_char in
      Object.Fixnum (int_of_string acc))
  in
  loop acc
;;

let is_symbol_start_char =
  let is_alpha = function
    | 'A' .. 'Z' | 'a' .. 'z' -> true
    | _ -> false
  in
  function
  | '*' | '/' | '>' | '<' | '=' | '?' | '!' | '-' | '+' -> true
  | a_char -> is_alpha a_char
;;

let rec read_symbol a_stream =
  let literal_quote = '"' in
  let is_delimiter = function
    | '(' | ')' | '{' | '}' | ';' -> true
    | a_char when a_char = literal_quote -> true
    | a_char -> is_whitespace a_char
  in
  let next_char = read_char a_stream in
  if is_delimiter next_char
  then (
    let _ = unread_char a_stream next_char in
    "")
  else string_of_char next_char ^ read_symbol a_stream
;;

let is_boolean a_char = Char.equal a_char '#'

let rec read_boolean a_stream =
  match read_char a_stream with
  | 't' -> Object.Boolean true
  | 'f' -> Object.Boolean false
  | x -> raise (Syntax_error_exn ("Invalid boolean literal '" ^ Char.escaped x))
;;

(** Read in a whole number *)
let rec read_sexp a_stream =
  let _ = eat_whitespace a_stream in
  let a_char = read_char a_stream in
  if is_symbol_start_char a_char
  then Object.Symbol (string_of_char a_char ^ read_symbol a_stream)
  else if is_digit a_char || Char.equal a_char '~'
  then
    (if Char.equal '~' a_char then '-' else a_char)
    |> Char.escaped
    |> read_fixnum a_stream
  else if is_boolean a_char
  then read_boolean a_stream
  else raise (Syntax_error_exn ("Unexcepted character '" ^ Char.escaped a_char))
;;
