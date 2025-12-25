(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_error
open Mlisp_lexer
open Mlisp_ast
open Mlisp_eval
open Core

(** Module loader for loading MLisp modules from files.

    This module provides functionality to load MLisp modules from files,
    resolve module paths, and evaluate module definitions. *)

(** Resolve module file path from module name.

    Converts a module name (e.g., "math" or "utils.string") into a file path.
    Supports both simple module names and hierarchical module paths.

    @param module_name Module name to resolve
    @param search_paths List of directories to search for module files
    @return Resolved file path
    @raise Errors.Runtime_error_exn if module file not found *)
let resolve_module_path module_name search_paths =
  let module_file = [%string "%{module_name}.mlisp"] in
  let rec search = function
    | [] ->
      raise
        (Errors.Runtime_error_exn
           (Errors.Module_load_error
              ( module_name
              , [%string "Module file '%{module_file}' not found in search paths"] )))
    | path :: rest ->
      let full_path = Filename.concat path module_file in
        match Core_unix.access full_path [ `Exists ] with
        | Ok () ->
          full_path
        | Error _ ->
          search rest
  in
    search search_paths

(** Load and evaluate a module from a file.

    Reads a module file, parses it, and evaluates it in the given environment.
    The file should contain a single module definition.

    @param file_path Path to the module file
    @param env Environment to evaluate the module in
    @return Updated environment with module loaded
    @raise Errors.Runtime_error_exn if file cannot be read or module cannot be evaluated *)
let load_module_from_file file_path env =
  try
    let input_channel = In_channel.create file_path in
    let stream = Mlisp_utils.Stream_wrapper.make_filestream input_channel ~file_name:file_path in
    let rec load_all env =
      try
        let ast = stream |> Lexer.read_sexpr |> Ast.build_ast in
        let _, updated_env = Eval.eval ast env in
          load_all updated_env
      with
      | Stream.Failure ->
        env
      | exn ->
        In_channel.close input_channel;
        raise exn
    in
    let result_env = load_all env in
      In_channel.close input_channel;
      result_env
  with
  | Sys_error msg ->
    raise
      (Errors.Runtime_error_exn
         (Errors.Module_load_error (file_path, [%string "File error: %{msg}"])))
  | exn ->
    raise
      (Errors.Runtime_error_exn
         (Errors.Module_load_error
            ( file_path
            , [%string "Evaluation error: %{Mlisp_error.Message.message exn}"] )))

(** Load a module by name.

    Resolves the module path and loads the module from file. The module
    must be defined in the loaded file and will be available in the returned
    environment.

    @param module_name Name of the module to load
    @param search_paths List of directories to search for module files
    @param env Environment to load the module into
    @return Updated environment with module loaded
    @raise Errors.Runtime_error_exn if module cannot be found or loaded *)
let load_module module_name search_paths env =
  let file_path = resolve_module_path module_name search_paths in
    load_module_from_file file_path env

(** Get default module search paths.

    Returns a list of default directories where modules are searched.
    Currently includes the current directory and a standard modules directory.

    @return List of search path strings *)
let default_search_paths () =
  let current_dir = Core_unix.getcwd () in
  let modules_dir = Filename.concat current_dir "modules" in
    [ current_dir; modules_dir ]
