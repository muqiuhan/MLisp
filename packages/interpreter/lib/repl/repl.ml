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
  input |> String.strip ~drop:(Char.equal '(') |> String.strip ~drop:(Char.equal ')')
;;

(** Generate completion hints for REPL input using optimized environment lookup.

    Provides intelligent code completion suggestions by searching through the
    current environment's bindings. Utilizes the hash-table based environment
    for O(1) lookups during hint generation.

    @param env Current environment with hash-table based bindings
    @param input User input string to generate hints for
    @return Optional hint tuple (text, color, completion_flag) *)
let hints
  : Object.lobject Object.env -> string -> (string * LNoise.hint_color * bool) option
  =
  fun env input ->
  let substring = drop_rackets input in
  let result = ref None in
    Hashtbl.iteri env.Object.bindings ~f:(fun ~key:name ~data:_ ->
      match !result with
      | None when String.is_substring ~substring name ->
        result := Some name
      | _ ->
        ());
    !result |> Option.map ~f:(fun definition -> definition, LNoise.Blue, true)
;;

(** Generate tab completion suggestions using optimized environment traversal.

    Provides comprehensive code completion by iterating through all bindings in
    the hash-table based environment. Optimized for performance with efficient
    substring matching and completion generation.

    @param env Environment containing all available bindings
    @param input Current user input for completion
    @param completions LNoise completion object to populate *)
let completion : Object.lobject Object.env -> string -> LNoise.completions -> unit =
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

let rec repl stream env ~has_error =
  (* Only set up LNoise in REPL mode to avoid blocking in file mode *)
  if stream.repl_mode then (
    LNoise.set_hints_callback (hints env);
    LNoise.set_completion_callback (completion env);
    LNoise.set_multiline true;
    LNoise.history_load ~filename:".mlisp-repl-history" |> ignore
  );
  (* For file mode, populate recent_input with file contents once *)
  if (not stream.repl_mode) && List.is_empty stream.recent_input then (
    try
      let lines = In_channel.read_lines stream.file_name in
        stream.recent_input <- lines
    with
    | _ ->
      ()
  );
  let input_stream =
    if stream.repl_mode then (
      let input =
        Ocamline.read
          ~delim:";;"
          ~brackets:[ '(', ')' ]
          ~prompt:prompt_tip
          ~trim_delim:false
          ~history_loc:".mlisp-repl-history"
          ~completion_callback:(completion env)
          ~hints_callback:(hints env)
          ()
      in
      let input_stream = Mlisp_utils.Stream_wrapper.make_stringstream input in
      (* Save input for error context - ensure we have at least one non-empty line *)
      let lines = String.split input ~on:'\n' in
      let lines =
        if
          List.is_empty lines
          || (List.length lines = 1 && String.is_empty (List.hd_exn lines))
        then
          [ input ]
        else
          (* Filter out empty trailing lines *) List.filter lines ~f:(fun line ->
            not (String.is_empty line))
      in
      let lines =
        if List.is_empty lines then
          [ input ]
        else
          lines
      in
        stream.recent_input <- lines;
        input_stream
    ) else
      stream
  in
    try
      (* Skip whitespace and comments BEFORE saving position for error reporting.
         This ensures the saved position points to the actual expression start. *)
      Lexer.skip_leading_whitespace_and_comments input_stream;
      (* Save position after skipping whitespace - this is where expression starts *)
      let saved_line = !(input_stream.line_num) in
      let saved_column = !(input_stream.column) in
      (* Read the expression body (without skipping whitespace again) *)
      let ast = input_stream |> Lexer.read_sexpr_body |> Ast.build_ast in
      (* Save the position after reading (for next iteration) *)
      let final_line = !(input_stream.line_num) in
      let final_column = !(input_stream.column) in
      (* Restore position for error reporting (in case of runtime errors) *)
      let _ = input_stream.line_num := saved_line in
      let _ = input_stream.column := saved_column in
        (* Set stream context for warnings *)
        Eval.set_stream stream;
        let result, env' = Eval.eval ast env in
          Eval.clear_stream ();
          (* Restore final position for next iteration *)
          input_stream.line_num := final_line;
          input_stream.column := final_column;
          if stream.repl_mode then (
            print_result result;
            stream.line_num := 0
          );
          repl stream env' ~has_error
    with
    | Stream.Failure ->
      if stream.repl_mode then
        Out_channel.newline Out_channel.stdout
      (* In file mode, Stream.Failure means end of file, not an error *)
    | Errors.Syntax_error_exn e ->
      (* In REPL mode, use stream to access recent_input, but update position from input_stream *)
      if stream.repl_mode then (
        stream.line_num := !(input_stream.line_num);
        stream.column := !(input_stream.column)
      );
      Mlisp_print.Error.print_error
        (if stream.repl_mode then
           stream
         else
           input_stream)
        (Errors.Syntax_error_exn e);
      if stream.repl_mode then
        repl stream env ~has_error
      else (
        has_error := true;
        repl stream env ~has_error
      )
    | Errors.Parse_error_exn e ->
      (* In REPL mode, use stream to access recent_input, but update position from input_stream *)
      if stream.repl_mode then (
        stream.line_num := !(input_stream.line_num);
        stream.column := !(input_stream.column)
      );
      Mlisp_print.Error.print_error
        (if stream.repl_mode then
           stream
         else
           input_stream)
        (Errors.Parse_error_exn e);
      if stream.repl_mode then
        repl stream env ~has_error
      else (
        has_error := true;
        repl stream env ~has_error
      )
    | Errors.Runtime_error_exn e ->
      (* In REPL mode, use stream to access recent_input, but update position from input_stream *)
      if stream.repl_mode then (
        stream.line_num := !(input_stream.line_num);
        stream.column := !(input_stream.column)
      );
      Mlisp_print.Error.print_error
        (if stream.repl_mode then
           stream
         else
           input_stream)
        (Errors.Runtime_error_exn e);
      if stream.repl_mode then
        repl stream env ~has_error
      else (
        has_error := true;
        repl stream env ~has_error
      )
    | End_of_file ->
      print_endline "Goodbye!"
    | e ->
      raise e
;;
