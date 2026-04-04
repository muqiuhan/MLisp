(* packages/interpreter/lib/lexer/location.ml *)
open Core

type t = {
  line : int;
  column : int;
  offset : int;
  file : string;
}

let make ~line ~column ~offset ~file = { line; column; offset; file }
let make_default ?(file="<unknown>") () = { line=1; column=1; offset=0; file }

let line t = t.line
let column t = t.column
let offset t = t.offset
let file t = t.file

let to_string t = sprintf "%s:%d:%d" t.file t.line t.column

let pp fmt t = Format.fprintf fmt "%s" (to_string t)
