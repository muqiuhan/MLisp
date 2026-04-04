(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Mlisp_utils.Stream_wrapper
open Core

let get_location : char stream -> Location.t =
  fun stream ->
  Location.make
    ~line:!(stream.line_num)
    ~column:!(stream.column)
    ~offset:!(stream.offset)
    ~file:stream.file_name
;;

let syntax_error_at : char stream -> string -> 'a =
  fun stream msg ->
  let loc = get_location stream in
  raise (Errors.Syntax_error_exn (Unexcepted_character (sprintf "%s: %s" (Location.to_string loc) msg)))
;;

let read_char : char stream -> char =
  fun stream ->
  match stream.chars with
  | [] -> (
    match Stream.next stream.stream with
    | next_char when Char.(next_char = '\n') ->
      incr stream.line_num;
      stream.column := 0;
      incr stream.offset;
      next_char
    | next_char ->
      incr stream.column;
      incr stream.offset;
      next_char)
  | current_char :: rest ->
    stream.chars <- rest;
    incr stream.offset;
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

(** Skip all leading whitespace and comments before an expression.

    This function is used by the REPL to find the actual start position
    of an expression before saving it for error reporting. Unlike
    eat_whitespace, this also handles comment lines.

    @param stream The input stream
    @return unit *)
let rec skip_leading_whitespace_and_comments : char stream -> unit =
  fun stream ->
  (* First, skip whitespace *)
  eat_whitespace stream;
  (* Check if the next character starts a comment *)
  let ch = peek_char stream in
    if Char.equal ch '\000' then
      (* End of input *)
      ()
    else if Char.equal ch ';' then (
      (* It's a comment, eat it and continue skipping *)
      let _ = read_char stream in
        eat_comment stream;
        skip_leading_whitespace_and_comments stream
    ) else
      (* Not a comment, we're at the start of the expression *)
      ()
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
  try
    let next_char = read_char stream in
      if is_delimiter next_char then (
        let _ = unread_char stream next_char in
          ""
      ) else
        try
          Object.string_of_char next_char ^ read_symbol stream
        with Stream.Failure -> Object.string_of_char next_char
  with Stream.Failure -> ""
;;

let read_boolean : char stream -> Object.lobject =
  fun stream ->
  match read_char stream with
  | 't' ->
    Object.Boolean true
  | 'f' ->
    Object.Boolean false
  | x ->
    let loc = get_location stream in
    raise (Errors.Syntax_error_exn (Invalid_boolean_literal (sprintf "%s: invalid boolean literal '#%s'" (Location.to_string loc) (Char.escaped x))))
;;

let read_string : char stream -> Object.lobject =
  fun stream ->
  let loc = get_location stream in
  let rec loop acc =
    let ch =
      try read_char stream
      with Stream.Failure ->
        raise (Errors.Syntax_error_exn (Unexcepted_character (
          sprintf "%s: unterminated string \"%s\"" (Location.to_string loc) acc)))
    in
      if Char.equal ch '"' then
        Object.String acc
      else if Char.equal ch '\\' then
        (* Handle escape sequences *)
        let esc = read_char stream in
        let char_to_add = match esc with
          | 'n' -> '\n'
          | 't' -> '\t'
          | '"' -> '"'
          | '\\' -> '\\'
          | _ ->
            raise (Errors.Syntax_error_exn (Errors.Invalid_escape {
              escape = esc;
              location = Location.to_string loc
            }))
        in
        loop (acc ^ String.make 1 char_to_add)
      else
        loop (acc ^ String.make 1 ch)
  in
    loop ""
;;

(** Read in a whole S-expression.

    This is the main entry point for reading expressions. It handles
    leading whitespace and comments before reading the expression.

    For special cases where you've already skipped leading whitespace,
    use read_sexpr_body directly. *)
let rec read_sexpr : char stream -> Object.lobject =
  fun stream ->
  (* Skip leading whitespace and comments to find the actual expression start *)
  skip_leading_whitespace_and_comments stream;
  (* Now read the expression body *)
  read_sexpr_body stream

(** Read in a whole number or float (internal version without leading whitespace skip).

    This function expects the stream to already be positioned at the first
    character of the expression. It reads the expression and any necessary
    sub-expressions (with whitespace skipping for sub-expressions).

    Use read_sexpr for normal reading which handles leading whitespace.
    Use read_sexpr_body when you've already skipped leading whitespace. *)
and read_sexpr_body : char stream -> Object.lobject =
  fun stream ->
  match read_char stream with
  | ch when Char.(ch = ';') ->
    eat_comment stream;
    eat_whitespace stream;
    read_sexpr_body stream
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
            (* Trailing dot is valid for floats: 5. = 5.0 *)
            Object.Float (float_of_string float_str)
          )
      ) else (
        unread_char stream after_digits;
        Object.Fixnum (int_of_string !num_str)
      )
  | ch when Char.equal ch '.' ->
    (* Leading dot float: .5 *)
    let next_ch = read_char stream in
      if Char.is_digit next_ch then
        read_float stream ("." ^ Char.escaped next_ch)
      else (
        unread_char stream next_ch;
        Object.Symbol "."
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
                (* Trailing dot is valid for floats: -5. = -5.0 *)
                Object.Float (float_of_string float_str)
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
    let loc = get_location stream in
    raise (Errors.Syntax_error_exn (Unexcepted_character (sprintf "%s: unexpected character '%s'" (Location.to_string loc) (Char.escaped ch))))

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
