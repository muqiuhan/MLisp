(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_ast
open Mlisp_lexer
open Mlisp_eval
open Mlisp_error
open Mlisp_utils.Stream_wrapper
open Mlisp_vars.Repl
open Core

let print_result result =
  Printf.printf
    "- : %s = %s\n\n"
    (Object.object_type result)
    (Object.string_object result);
  Out_channel.flush Out_channel.stdout
;;

let drop_rackets input =
  input
  |> String.strip ~drop:(Char.equal '(')
  |> String.strip ~drop:(Char.equal ')')
;;

(** Generate completion hints for REPL input using optimized environment lookup.

    Provides intelligent code completion suggestions by searching through
    the current environment's bindings. Utilizes the hash-table based
    environment for O(1) lookups during hint generation.

    @param env Current environment with hash-table based bindings
    @param input User input string to generate hints for
    @return Optional hint tuple (text, color, completion_flag)
*)
let hints
  :  Object.lobject Object.env
  -> string
  -> (string * LNoise.hint_color * bool) option
  =
  fun env input ->
  let substring = drop_rackets input in
  let result = ref None in
    Hashtbl.iteri env.Object.bindings ~f:(fun ~key:name ~data:_ ->
      match !result with
      | None when String.is_substring ~substring name -> result := Some name
      | _ -> ());
    !result |> Option.map ~f:(fun definition -> definition, LNoise.Blue, true)
;;

(** Generate tab completion suggestions using optimized environment traversal.

    Provides comprehensive code completion by iterating through all bindings
    in the hash-table based environment. Optimized for performance with
    efficient substring matching and completion generation.

    @param env Environment containing all available bindings
    @param input Current user input for completion
    @param completions LNoise completion object to populate
*)
let completion
  : Object.lobject Object.env -> string -> LNoise.completions -> unit
  =
  fun env input completions ->
  let definitions = ref [] in
    Hashtbl.iteri env.Object.bindings ~f:(fun ~key:name ~data:_ ->
      definitions := name :: !definitions);
    !definitions
    |> List.filter ~f:(fun definition ->
      String.is_substring ~substring:(drop_rackets input) definition)
    |> List.iter ~f:(fun completion ->
      let count =
        String.count input ~f:(fun ch ->
          Mlisp_lexer.Lexer.is_symbol_start_char ch || Char.is_digit ch)
      in
      let completion =
        String.substr_replace_first
          ~pattern:(String.sub completion ~pos:0 ~len:count)
          ~with_:completion
          input
      in
        LNoise.add_completion completions completion)
;;

let rec repl stream env =
  LNoise.set_hints_callback (hints env);
  LNoise.set_completion_callback (completion env);
  LNoise.set_multiline true;
  LNoise.history_load ~filename:".mlisp-repl-history" |> ignore;
  try
    let ast =
      begin
        if stream.repl_mode then
          Ocamline.read
            ~delim:";;"
            ~brackets:[ '(', ')' ]
            ~prompt:prompt_tip
            ~trim_delim:false
            ~history_loc:".mlisp-repl-history"
            ~completion_callback:(completion env)
            ~hints_callback:(hints env)
            ()
          |> Mlisp_utils.Stream_wrapper.make_stringstream
        else
          stream
      end
      |> Lexer.read_sexpr
      |> Ast.build_ast
    in
    let result, env' = Eval.eval ast env in
      if stream.repl_mode then begin
        print_result result;
        stream.line_num := 0
      end;
      repl stream env'
  with
  | Stream.Failure ->
    if stream.repl_mode then Out_channel.newline Out_channel.stdout
  | Errors.Syntax_error_exn e ->
    Mlisp_print.Error.print_error stream (Errors.Syntax_error_exn e);
    if stream.repl_mode then repl stream env
  | Errors.Parse_error_exn e ->
    Mlisp_print.Error.print_error stream (Errors.Parse_error_exn e);
    if stream.repl_mode then repl stream env
  | Errors.Runtime_error_exn e ->
    Mlisp_print.Error.print_error stream (Errors.Runtime_error_exn e);
    if stream.repl_mode then repl stream env
  | End_of_file -> print_endline "Goodbye!"
  | e -> raise e
;;
