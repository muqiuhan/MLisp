(* packages/interpreter/lib/lexer/lexer_error.ml *)
open Core

type t =
  | Unexpected_char of {
      found : char;
      location : Location.t;
      expected : string option;
    }
  | Unterminated_string of {
      location : Location.t;
      start_loc : Location.t;
    }
  | Invalid_escape of {
      escape : char;
      location : Location.t;
    }
  | Invalid_number of {
      text : string;
      location : Location.t;
    }
  | Invalid_float of {
      text : string;
      location : Location.t;
    }

exception Lexer_exn of t

let format_error (e : t) : string =
  let loc_str loc = Location.to_string loc in
  match e with
  | Unexpected_char { found; location; expected } ->
    let expected_str = Option.value_map expected ~default:"" ~f:(sprintf " expected %s") in
    sprintf "%s: unexpected character '%s'%s" (loc_str location) (Char.escaped found) expected_str
  | Unterminated_string { location; start_loc } ->
    sprintf "%s: unterminated string (started at %s)" (loc_str location) (loc_str start_loc)
  | Invalid_escape { escape; location } ->
    sprintf "%s: invalid escape sequence '\\%s'" (loc_str location) (Char.escaped escape)
  | Invalid_number { text; location } ->
    sprintf "%s: invalid number '%s'" (loc_str location) text
  | Invalid_float { text; location } ->
    sprintf "%s: invalid float '%s'" (loc_str location) text

let pp_error fmt e = Format.fprintf fmt "%s" (format_error e)
