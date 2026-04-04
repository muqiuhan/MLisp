(* packages/interpreter/lib/lexer/tokenizer.ml *)
open Core
open Token
open Lexer_error
open Mlisp_utils.Stream_wrapper
module R = Mlisp_error.Result
open R

let is_whitespace = Char.is_whitespace
let is_digit = Char.is_digit

let is_symbol_char = function
  | '*' | '/' | '>' | '<' | '=' | '?' | '!' | '-' | '+' | ':' | '$' | '@' | '|' | '\\' | '`' | '&' | '%' -> true
  | c -> Char.is_alphanum c || Char.equal c '_'

type t = {
  stream : char stream;
  mutable current_loc : Location.t;
  mutable unread_char : char option;
}

let create stream = {
  stream;
  current_loc = Location.make_default ~file:stream.file_name ();
  unread_char = None;
}

let current_location t = t.current_loc

let read_char t =
  match t.unread_char with
  | Some c ->
    t.unread_char <- None;
    c
  | None ->
    let c =
      match t.stream.chars with
      | [] -> (
        try
          match Stream.next t.stream.stream with
          | next_char when Char.equal next_char '\n' ->
            incr t.stream.line_num;
            t.stream.column := 0;
            next_char
          | next_char ->
            incr t.stream.column;
            next_char
        with
        | Stream.Failure -> '\000')
      | current_char :: rest ->
        t.stream.chars <- rest;
        current_char
    in
    if Char.equal c '\n' then (
      t.current_loc <- { t.current_loc with Location.line = t.current_loc.Location.line + 1; Location.column = 1; Location.offset = t.current_loc.Location.offset + 1 }
    ) else (
      t.current_loc <- { t.current_loc with Location.column = t.current_loc.Location.column + 1; Location.offset = t.current_loc.Location.offset + 1 }
    );
    c

let unread_char t c = t.unread_char <- Some c

let peek_char t =
  match t.unread_char with
  | Some c -> c
  | None -> (
    match t.stream.chars with
    | current_char :: _ -> current_char
    | [] -> (
      match Stream.peek t.stream.stream with
      | Some next_char -> next_char
      | None -> '\000'))

let rec skip_whitespace_and_comments t =
  let c = peek_char t in
  if Char.equal c '\000' then ()
  else if Char.is_whitespace c then (
    let _ = read_char t in
    skip_whitespace_and_comments t
  ) else if Char.equal c ';' then (
    let _ = read_char t in
    skip_comment t;
    skip_whitespace_and_comments t
  ) else ()

and skip_comment t =
  let c = read_char t in
  if Char.equal c '\n' || Char.equal c '\000' then ()
  else skip_comment t

let read_number t start_char =
  let acc = Buffer.create 16 in
  Buffer.add_char acc start_char;
  let rec loop () =
    let c = peek_char t in
    if Char.is_digit c then (
      Buffer.add_char acc (read_char t);
      loop ()
    ) else if Char.equal c '.' then (
      Buffer.add_char acc (read_char t);
      read_float_part acc
    ) else (
      let text = Buffer.contents acc in
      try T_Number (int_of_string text) with
      | Failure _ -> T_Float (float_of_string text)
    )
  and read_float_part acc =
    let c = peek_char t in
    if Char.is_digit c then (
      Buffer.add_char acc (read_char t);
      read_float_part acc
    ) else (
      let text = Buffer.contents acc in
      if String.is_suffix text ~suffix:"." then (
        unread_char t '.';
        let num_text = String.drop_suffix text 1 in
        T_Number (int_of_string num_text)
      ) else (
        T_Float (float_of_string text)
      )
    )
  in
  loop ()

let read_string t start_loc =
  let acc = Buffer.create 64 in
  let rec loop () =
    let c = read_char t in
    if Char.equal c '"' then (
      R.return (Buffer.contents acc)
    ) else if Char.equal c '\\' then (
      let esc = read_char t in
      let char_to_add = match esc with
        | 'n' -> Some '\n'
        | 't' -> Some '\t'
        | '"' -> Some '"'
        | '\\' -> Some '\\'
        | _ -> None
      in
      (match char_to_add with
        | Some ch -> Buffer.add_char acc ch; R.(R.return () >>= fun () -> loop ())
        | None ->
          unread_char t esc;
          R.fail (Invalid_escape { escape = esc; location = current_location t }))
    ) else if Char.equal c '\000' then (
      R.fail (Unterminated_string { location = current_location t; start_loc = start_loc })
    ) else (
      Buffer.add_char acc c;
      loop ()
    )
  in
  loop ()

let read_symbol_text text =
  match text with
  | "true" | "#t" -> T_Boolean true
  | "false" | "#f" -> T_Boolean false
  | _ -> T_Symbol text

let read_symbol t start_char =
  let acc = Buffer.create 16 in
  Buffer.add_char acc start_char;
  let rec loop () =
    let c = peek_char t in
    if is_symbol_char c && not (Char.is_whitespace c) then (
      Buffer.add_char acc (read_char t);
      loop ()
    ) else (
      read_symbol_text (Buffer.contents acc)
    )
  in
  loop ()

let next t : (Token.t, Lexer_error.t) result =
  skip_whitespace_and_comments t;
  let start_loc = current_location t in
  let c = read_char t in
  
  if Char.equal c '\000' then R.return (Token.make T_EOF ~loc:start_loc ~text:"")
  else if Char.equal c '(' then R.return (Token.make T_Lparen ~loc:start_loc ~text:"(")
  else if Char.equal c ')' then R.return (Token.make T_Rparen ~loc:start_loc ~text:")")
  else if Char.equal c '\'' then R.return (Token.make T_Quote ~loc:start_loc ~text:"'")
  else if Char.equal c '`' then R.return (Token.make T_Backquote ~loc:start_loc ~text:"`")
  else if Char.equal c ',' then (
    if Char.equal (peek_char t) '@' then (
      let _ = read_char t in
      R.return (Token.make T_CommaAt ~loc:start_loc ~text:",@")
    ) else (
      R.return (Token.make T_Comma ~loc:start_loc ~text:",")
    )
  ) else if Char.equal c '#' then (
    let next_c = read_char t in
    if Char.equal next_c 't' then R.return (Token.make (T_Boolean true) ~loc:start_loc ~text:"#t")
    else if Char.equal next_c 'f' then R.return (Token.make (T_Boolean false) ~loc:start_loc ~text:"#f")
    else R.fail (Unexpected_char { found=next_c; location=start_loc; expected=Some "'t' or 'f'" })
  ) else if Char.equal c '"' then (
    read_string t start_loc >>= fun s ->
    return (Token.make (T_String s) ~loc:start_loc ~text:(sprintf "\"%s\"" s))
  ) else if Char.is_digit c || (Char.equal c '-' && Char.is_digit (peek_char t)) then (
    let num_tok = read_number t c in
    let text = match num_tok with T_Number n -> Int.to_string n | T_Float f -> Float.to_string f | _ -> "" in
    R.return (Token.make num_tok ~loc:start_loc ~text)
  ) else if is_symbol_char c then (
    let sym_tok = read_symbol t c in
    let text = match sym_tok with T_Symbol s -> s | T_Boolean b -> if b then "#t" else "#f" | _ -> "" in
    R.return (Token.make sym_tok ~loc:start_loc ~text)
  ) else (
    R.fail (Unexpected_char { found=c; location=start_loc; expected=None })
  )

let rec tokenize_all t acc =
  match next t with
  | Ok tok -> (
    if Token.equal_kind (Token.kind tok) T_EOF then
      List.rev acc
    else
      tokenize_all t (tok :: acc)
  )
  | Error e -> raise (Lexer_error.Lexer_exn e)