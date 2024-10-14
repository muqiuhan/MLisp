(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Mlisp_utils.Stream_wrapper
open Mlisp_vars
open Core

let read_char : char stream -> char =
  fun stream ->
  match stream.chars with
  | [] ->
      let next_char = Stream.next stream.stream in
          if Char.(next_char = '\n') then (
            stream.line_num <- stream.line_num + 1;
            stream.column <- 0;
            next_char
          ) else (
            stream.column <- stream.column + 1;
            next_char
          )
  | current_char :: rest ->
      stream.chars <- rest;
      current_char
;;

let unread_char : 'a stream -> char -> unit =
  fun stream current_char -> stream.chars <- current_char :: stream.chars
;;

let rec eat_whitespace : char stream -> unit =
  fun stream ->
  let ch = read_char stream in
      if Char.is_whitespace ch then
        eat_whitespace stream
      else
        unread_char stream ch
;;

let rec eat_comment : char stream -> unit =
  fun stream ->
  if Char.(read_char stream = '\n') then
    ()
  else
    eat_comment stream
;;

let read_fixnum : char stream -> char -> Object.lobject =
  fun stream prefix ->
  let acc =
    (if Char.('~' = prefix) then
       '-'
     else
       prefix)
    |> Char.escaped
in
  let rec loop acc =
    let num_char = read_char stream in
        if Char.is_digit num_char then
          num_char |> Char.escaped |> ( ^ ) acc |> loop
        else (
          let _ = unread_char stream num_char in
              Object.Fixnum (int_of_string acc)
        )
in
      loop acc
;;

let is_symbol_start_char : char -> bool = function
  | '*'
  | '/'
  | '>'
  | '<'
  | '='
  | '?'
  | '!'
  | '-'
  | '+'
  | ':'
  | '$'
  | '@'
  | '|'
  | '\\'
  | '`'
  | '&'
  | '%' ->
      true
  | ch ->
      Char.is_alpha ch
;;

let rec read_symbol : char stream -> string =
  fun stream ->
  let is_delimiter = function
    | '(' | ')' | '{' | '}' | ';' ->
        true
    | ch ->
        Char.is_whitespace ch
in
  let next_char = read_char stream in
      if is_delimiter next_char then (
        let _ = unread_char stream next_char in
            ""
      ) else
        Object.string_of_char next_char ^ read_symbol stream
;;

let read_boolean : char stream -> Object.lobject =
  fun stream ->
  match read_char stream with
  | 't' ->
      Object.Boolean true
  | 'f' ->
      Object.Boolean false
  | x ->
      raise (Errors.Syntax_error_exn (Invalid_boolean_literal (Char.escaped x)))
;;

let read_string : char stream -> Object.lobject =
  fun stream ->
  let rec loop acc =
    let ch = read_char stream in
        if Char.equal ch '"' then
          Object.String acc
        else
          ch |> Char.escaped |> ( ^ ) acc |> loop
in
      loop ""
;;

(** Read in a whole number *)
let rec read_sexpr : char stream -> Object.lobject =
  fun stream ->
  eat_whitespace stream;
  match read_char stream with
  | ch when Char.(ch = ';') ->
      eat_comment stream;
      read_sexpr stream
  | ch when Char.(is_digit ch || ch = '~') ->
      read_fixnum stream ch
  | ch when Char.(ch = '(') ->
      read_list stream
  | ch when Char.(ch = '#') ->
      read_boolean stream
  | ch when Char.(ch = '\'') ->
      Quote (read_sexpr stream)
  | ch when Char.(ch = '\"') ->
      read_string stream
  | ch when is_symbol_start_char ch ->
      Object.Symbol (Object.string_of_char ch ^ read_symbol stream)
  | ch ->
      raise (Errors.Syntax_error_exn (Unexcepted_character (Char.escaped ch)))

and read_list : char stream -> Object.lobject =
  fun stream ->
  (* Better REPL *)
  (let ch = read_char stream in
       if stream.repl_mode && Char.equal ch '\n' then (
         print_string (String.make (String.length Repl.prompt_tip - 1) ' ' ^ "| ");
         Out_channel.flush stdout
       ) else
         unread_char stream ch);
  eat_whitespace stream;
  let ch = read_char stream in
      if Char.(ch = ')') then
        Nil
      else (
        unread_char stream ch;
        let car = read_sexpr stream in
        let cdr = read_list stream in
            Pair (car, cdr)
      )
;;
