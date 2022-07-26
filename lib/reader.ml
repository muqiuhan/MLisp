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

open Types.Reader
open Types.Object

let make_stream ?(file_name = "stdin") is_stdin stm =
  { chrs = []; line_num = 1; stdin = is_stdin; stm; file_name; column_number = 0 }
;;

let make_stringstream s = make_stream false @@ Stream.of_string s

let make_filestream ?(file_name = "stdin") f =
  make_stream ~file_name (f = stdin) @@ Stream.of_channel f
;;

let read_char a_stream =
  match a_stream.chrs with
  | [] ->
    let a_char = Stream.next a_stream.stm in
    if a_char = '\n'
    then (
      let _ = a_stream.line_num <- a_stream.line_num + 1 in
      let _ = a_stream.column_number <- 0 in
      a_char)
    else (
      let _ = a_stream.column_number <- a_stream.column_number + 1 in
      a_char)
  | a_char :: rest ->
    let _ = a_stream.chrs <- rest in
    a_char
;;

let unread_char a_stream a_char = a_stream.chrs <- a_char :: a_stream.chrs

let is_whitespace a_char =
  match a_char with
  | ' ' | '\t' | '\n' -> true
  | _ -> false
;;

let rec eat_whitespace a_stream =
  let a_char = read_char a_stream in
  if is_whitespace a_char then eat_whitespace a_stream else unread_char a_stream a_char
;;

let rec eat_comment a_stream =
  if read_char a_stream = '\n' then () else eat_comment a_stream
;;

let is_digit a_char =
  let code = Char.code a_char in
  code >= Char.code '0' && code <= Char.code '9'
;;

let read_fixnum a_stream acc =
  let rec loop acc =
    let num_char = read_char a_stream in
    if is_digit num_char
    then num_char |> Char.escaped |> ( ^ ) acc |> loop
    else (
      let _ = unread_char a_stream num_char in
      Fixnum (int_of_string acc))
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
  let is_delimiter = function
    | '(' | ')' | '{' | '}' | ';' -> true
    | a_char -> is_whitespace a_char
  in
  let next_char = read_char a_stream in
  if is_delimiter next_char
  then (
    let _ = unread_char a_stream next_char in
    "")
  else Object.string_of_char next_char ^ read_symbol a_stream
;;

let is_boolean a_char = Char.equal a_char '#'

let read_boolean a_stream =
  match read_char a_stream with
  | 't' -> Boolean true
  | 'f' -> Boolean false
  | x -> raise (Syntax_error_exn (Invalid_boolean_literal (Char.escaped x)))
;;

let read_string a_stream =
  let rec loop acc =
    let a_char = read_char a_stream in
    if Char.equal a_char '"'
    then String acc
    else a_char |> Char.escaped |> ( ^ ) acc |> loop
  in
  loop ""
;;

(** Read in a whole number *)
let rec read_sexpr a_stream =
  let _ = eat_whitespace a_stream in
  let a_char = read_char a_stream in
  if a_char = ';'
  then (
    eat_comment a_stream;
    read_sexpr a_stream)
  else if is_symbol_start_char a_char
  then Symbol (Object.string_of_char a_char ^ read_symbol a_stream)
  else if is_digit a_char || Char.equal a_char '~'
  then
    (if Char.equal '~' a_char then '-' else a_char)
    |> Char.escaped
    |> read_fixnum a_stream
  else if Char.equal a_char '('
  then read_list a_stream
  else if is_boolean a_char
  then read_boolean a_stream
  else if Char.equal a_char '\''
  then Quote (read_sexpr a_stream)
  else if Char.equal a_char '\"'
  then read_string a_stream
  else raise (Syntax_error_exn (Unexcepted_character (Char.escaped a_char)))

and read_list a_stream =
  eat_whitespace a_stream;
  let a_char = read_char a_stream in
  if a_char = ')'
  then Nil
  else (
    let _ = unread_char a_stream a_char in
    let car = read_sexpr a_stream in
    let cdr = read_list a_stream in
    Pair (car, cdr))
;;
