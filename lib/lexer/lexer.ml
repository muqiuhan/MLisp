(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Mlisp_utils.Stream_wrapper
open Core

let read_char : char stream -> char =
  fun stream ->
  match stream.chars with
  | [] -> (
    match Stream.next stream.stream with
    | next_char when Char.(next_char = '\n') ->
      incr stream.line_num;
      stream.column := 0;
      next_char
    | next_char ->
      incr stream.column;
      next_char)
  | current_char :: rest ->
    stream.chars <- rest;
    current_char
;;

let unread_char : 'a stream -> char -> unit =
  fun stream current_char -> stream.chars <- current_char :: stream.chars
;;

(** Peek at the next character without consuming it *)
let peek_char : char stream -> char =
  fun stream ->
  match stream.chars with
  | current_char :: _ ->
    current_char
  | [] -> (
    match Stream.peek stream.stream with
    | Some next_char ->
      next_char
    | None ->
      (* Return a sentinel value that won't match any valid character *)
      '\000')
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
    (if Char.('-' = prefix) then
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

let read_float : char stream -> string -> Object.lobject =
  fun stream acc ->
  let rec loop acc =
    let num_char = read_char stream in
      if Char.is_digit num_char then
        num_char |> Char.escaped |> ( ^ ) acc |> loop
      else (
        let _ = unread_char stream num_char in
          Object.Float (float_of_string acc)
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
    | '('
    | ')'
    | '{'
    | '}'
    | ';' ->
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

(** Read in a whole number or float *)
let rec read_sexpr : char stream -> Object.lobject =
  fun stream ->
  eat_whitespace stream;
  match read_char stream with
  | ch when Char.(ch = ';') ->
    eat_comment stream;
    read_sexpr stream
  | ch when Char.is_digit ch ->
    (* Read number, check if it's a float *)
    let num_str = ref (Char.escaped ch) in
    let rec read_digits () =
      let next_ch = read_char stream in
        if Char.is_digit next_ch then (
          num_str := !num_str ^ Char.escaped next_ch;
          read_digits ()
        ) else
          next_ch
    in
    let after_digits = read_digits () in
      if Char.equal after_digits '.' then (
        (* It's a float *)
        let float_str = !num_str ^ "." in
        let after_dot = read_char stream in
          if Char.is_digit after_dot then
            read_float stream (float_str ^ Char.escaped after_dot)
          else (
            unread_char stream after_dot;
            unread_char stream '.';
            Object.Fixnum (int_of_string !num_str)
          )
      ) else (
        unread_char stream after_digits;
        Object.Fixnum (int_of_string !num_str)
      )
  | ch when Char.(ch = '-') ->
    (* Check if it's a negative number or minus operator *)
    let next_ch = read_char stream in
      if Char.is_digit next_ch then (
        (* It's a negative number *)
        let num_str = ref ("-" ^ Char.escaped next_ch) in
        let rec read_digits () =
          let next_ch = read_char stream in
            if Char.is_digit next_ch then (
              num_str := !num_str ^ Char.escaped next_ch;
              read_digits ()
            ) else
              next_ch
        in
        let after_digits = read_digits () in
          if Char.equal after_digits '.' then (
            (* It's a negative float *)
            let float_str = !num_str ^ "." in
            let after_dot = read_char stream in
              if Char.is_digit after_dot then
                read_float stream (float_str ^ Char.escaped after_dot)
              else (
                unread_char stream after_dot;
                unread_char stream '.';
                Object.Fixnum (int_of_string !num_str)
              )
          ) else (
            unread_char stream after_digits;
            Object.Fixnum (int_of_string !num_str)
          )
      ) else (
        (* It's the minus operator symbol *)
        unread_char stream next_ch;
        Object.Symbol "-"
      )
  | ch when Char.(ch = '(') ->
    read_list stream
  | ch when Char.(ch = '#') ->
    read_boolean stream
  | ch when Char.(ch = '\'') ->
    Quote (read_sexpr stream)
  | ch when Char.(ch = '`') ->
    (* Quasiquote (backtick) *)
    Object.Quasiquote (read_sexpr stream)
  | ch when Char.(ch = ',') ->
    (* Unquote or unquote-splicing *)
    let next_char = peek_char stream in
      if Char.equal next_char '@' then (
        (* Consume the '@' *)
        let _ = read_char stream in
          Object.UnquoteSplicing (read_sexpr stream)
      ) else
        Object.Unquote (read_sexpr stream)
  | ch when Char.(ch = '\"') ->
    read_string stream
  | ch when is_symbol_start_char ch ->
    Object.Symbol (Object.string_of_char ch ^ read_symbol stream)
  | ch ->
    raise (Errors.Syntax_error_exn (Unexcepted_character (Char.escaped ch)))

and read_list : char stream -> Object.lobject =
  fun stream ->
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
