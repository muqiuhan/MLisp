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
open Types.Error
open Types.Ast
open Types.Eval

let message = function
  | Syntax_error_exn e ->
    "Syntax error -> "
    ^
    (match e with
    | Unexcepted_character c -> "Unexcepted character : '" ^ c ^ "'"
    | Invalid_boolean_literal b -> "Invalid boolean literal : '" ^ b ^ "'")
  | Parse_error_exn e ->
    "Parse error -> "
    ^
    (match e with
    | Unique_error p -> "Unique error : " ^ p
    | Type_error x -> "Type error : " ^ x
    | Poorly_formed_expression -> "Poorly formed expression.")
  | Runtime_error_exn e ->
    (match e with
    | Not_found e -> "Not found : " ^ e
    | Unspecified_value e -> "Unspecified value : " ^ e
    | Missing_argument args -> "Missing arguments : " ^ Utils.spacesep args)
  | _ -> "None"
;;

let help = function
  | Syntax_error_exn e ->
    (match e with
    | Unexcepted_character _ ->
      "Usually triggered by wrong characters, such as extra parentheses, etc."
    | Invalid_boolean_literal _ -> "Raised by incorrect boolean literals.")
  | Parse_error_exn e ->
    (match e with
    | Unique_error _ ->
      "A conflict error caused by duplicate parameter names when defining closure."
    | Type_error _ ->
      "Possible type error due to a function call with parameters of a type different \
       from that specified in the function definition."
    | Poorly_formed_expression -> "Syntactically incorrect or redundant elements.")
  | Runtime_error_exn e ->
    (match e with
    | Not_found _ -> "Accessing an identifier that has not been defined in the context."
    | Unspecified_value _ ->
      "Accessing an identifier that is not explicitly defined in the context."
    | Missing_argument _ ->
      "It is possible that the actual parameter quantity is inconsistent with the formal \
       parameter quantity")
  | _ -> "None"
;;

let repl_error { file_name; line_number; column_number; message; help } =
  Ocolor_format.printf
    "\n\
     @{<hi_white>|@} @{<hi_cyan>From : \"%s\" , Line: %d , Column: %d@}\n\
     @{<hi_white>|@} @{<hi_red>| Error: %s@}\n\
     @{<hi_white>|@} @{<hi_green>| Help : %s@}\n\n"
    file_name
    line_number
    column_number
    message
    help
;;

let file_error { file_name; line_number; column_number; message; help } =
  let split_line { file_name; line_number; column_number; message; help } line_value =
    let char_num =
      List.fold_left
        (fun max prev -> if prev > max then prev else max)
        (String.length
           (string_of_int line_number ^ string_of_int column_number ^ file_name)
        + 31)
        [ String.length message + 9
        ; String.length help + 9
        ; String.length line_value + 8
        ]
    in
    "+" ^ String.make (char_num + 4) '-'
  in
  let line_value = List.nth (Utils.read_lines file_name) (line_number - 1) in
  let split_line =
    split_line { file_name; line_number; column_number; message; help } line_value
  in
  let tip_mark = "+" ^ String.make (String.length line_value + 5) '-' ^ "^" in
  Ocolor_format.printf
    "\n\
     @{<hi_white>%s@}\n\
     @{<hi_white>|@} @{<hi_cyan>From : \"%s\" , Line: %d , Column: %d@}\n\
     @{<hi_white>|@}------> @{<hi_white>%s@}\n\
     @{<hi_white>|@} @{<hi_red>%s@}\n\
     @{<hi_white>|@} @{<hi_red>| Error: %s@}\n\
     @{<hi_white>|@} @{<hi_green>| Help : %s@}\n\
     @{<hi_white>%s@}\n"
    split_line
    file_name
    line_number
    column_number
    line_value
    tip_mark
    message
    help
    split_line
;;

let print_error (a_stream : 'a stream) exn =
  let data =
    { file_name = a_stream.file_name
    ; line_number = a_stream.line_num
    ; column_number = a_stream.column_number
    ; message = message exn
    ; help = help exn
    }
  in
  if a_stream.stdin
  then data |> repl_error |> ignore |> flush_all
  else data |> file_error |> ignore |> flush_all
;;
