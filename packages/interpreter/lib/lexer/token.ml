(* packages/interpreter/lib/lexer/token.ml *)
open Core

type kind =
  | T_Lparen | T_Rparen | T_Dot
  | T_Quote | T_Backquote | T_Comma | T_CommaAt
  | T_Boolean of bool
  | T_Number of int | T_Float of float
  | T_String of string
  | T_Symbol of string
  | T_EOF

type t = {
  kind : kind;
  loc : Location.t;
  text : string;
}

let make kind ~loc ~text = { kind; loc; text }
let kind t = t.kind
let loc t = t.loc
let text t = t.text

let equal_kind (a : kind) (b : kind) : bool =
  match a, b with
  | T_Lparen, T_Lparen -> true
  | T_Rparen, T_Rparen -> true
  | T_Dot, T_Dot -> true
  | T_Quote, T_Quote -> true
  | T_Backquote, T_Backquote -> true
  | T_Comma, T_Comma -> true
  | T_CommaAt, T_CommaAt -> true
  | T_Boolean x, T_Boolean y -> Bool.equal x y
  | T_Number x, T_Number y -> x = y
  | T_Float x, T_Float y -> Float.equal x y
  | T_String x, T_String y -> String.equal x y
  | T_Symbol x, T_Symbol y -> String.equal x y
  | T_EOF, T_EOF -> true
  | _ -> false

let pp_kind fmt = function
  | T_Lparen -> Format.pp_print_string fmt "T_Lparen"
  | T_Rparen -> Format.pp_print_string fmt "T_Rparen"
  | T_Dot -> Format.pp_print_string fmt "T_Dot"
  | T_Quote -> Format.pp_print_string fmt "T_Quote"
  | T_Backquote -> Format.pp_print_string fmt "T_Backquote"
  | T_Comma -> Format.pp_print_string fmt "T_Comma"
  | T_CommaAt -> Format.pp_print_string fmt "T_CommaAt"
  | T_Boolean b -> Format.fprintf fmt "T_Boolean(%b)" b
  | T_Number n -> Format.fprintf fmt "T_Number(%d)" n
  | T_Float f -> Format.fprintf fmt "T_Float(%f)" f
  | T_String s -> Format.fprintf fmt "T_String(%s)" s
  | T_Symbol s -> Format.fprintf fmt "T_Symbol(%s)" s
  | T_EOF -> Format.pp_print_string fmt "T_EOF"

let pp fmt t = Format.fprintf fmt "%a at %a" pp_kind t.kind Location.pp t.loc
