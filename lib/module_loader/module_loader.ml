(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_error
open Mlisp_lexer
open Mlisp_ast
open Mlisp_eval
open Mlisp_object
open Module_cache
open Core

(* Open Core_unix for timestamp functions *)
module Time = Core_unix

(** Module loader for loading MLisp modules from files.

    This module provides functionality to load MLisp modules from files,
    resolve module paths, evaluate module definitions, and cache loaded modules. *)

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
    | path :: rest -> (
      let full_path = Filename.concat path module_file in
        match Core_unix.access full_path [ `Exists ] with
        | Ok () ->
          full_path
        | Error _ ->
          search rest)
  in
    search search_paths
;;

(** Load and evaluate a module from a file.

    Reads a module file, parses it, and evaluates it in the given environment.
    Returns the resulting environment and the module object if found.

    @param file_path Path to the module file
    @param env Environment to evaluate the module in
    @return (module_object option, updated_environment)
    @raise Errors.Runtime_error_exn if file cannot be read or module cannot be evaluated *)
let load_module_from_file_with_module file_path env =
  try
    let input_channel = In_channel.create file_path in
    let stream =
      Mlisp_utils.Stream_wrapper.make_filestream input_channel ~file_name:file_path
    in
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

      (* Extract the module object from the environment if it exists *)
      (* The module file name (without extension) should match the module name *)
      let module_name = Filename.chop_extension (Filename.basename file_path) in
      let module_obj =
        try Some (Object.lookup (module_name, result_env))
        with
        | Errors.Runtime_error_exn _ -> None
      in
        module_obj, result_env
  with
  | Sys_error msg ->
    raise
      (Errors.Runtime_error_exn
         (Errors.Module_load_error (file_path, [%string "File error: %{msg}"])))
  | exn ->
    raise
      (Errors.Runtime_error_exn
         (Errors.Module_load_error
            (file_path, [%string "Evaluation error: %{Mlisp_error.Message.message exn}"])))
;;

(** Load and evaluate a module from a file (backward compatible version).

    This function only returns the environment, for compatibility with
    existing code that doesn't need the module object.

    @param file_path Path to the module file
    @param env Environment to evaluate the module in
    @return Updated environment
    @raise Errors.Runtime_error_exn if file cannot be read or module cannot be evaluated *)
let load_module_from_file file_path env =
  let _, result_env = load_module_from_file_with_module file_path env in
    result_env
;;

(** Load a module by name with caching and circular dependency detection.

    Resolves the module path and loads the module from file. The module
    must be defined in the loaded file and will be available in the returned
    environment. Loaded modules are cached for subsequent imports.

    @param module_name Name of the module to load
    @param search_paths List of directories to search for module files
    @param env Environment to load the module into
    @return Updated environment with module loaded
    @raise Errors.Runtime_error_exn if module cannot be found or loaded,
            or if circular dependency is detected *)
let load_module module_name search_paths env =
  let cache_ref = get_global_cache () in
  let state = !cache_ref in
  let string_equal = String.equal in

  (* Check for circular dependency *)
  let is_loading = List.exists state.currently_loading ~f:(fun m -> string_equal m module_name) in
  if is_loading then (
    let cycle_path = String.concat ~sep:" -> " (List.rev (module_name :: state.currently_loading)) in
      raise
        (Errors.Runtime_error_exn
           (Errors.Module_load_error
              ( module_name
              , [%string "Circular dependency detected: %{cycle_path}"] )))
  );

  (* Check cache *)
  match Hashtbl.find state.cache module_name with
  | Some cached ->
      (* Cache hit - bind the module object to the current environment *)
      Object.bind (module_name, cached.module_object, env) |> ignore;
      env
  | None ->
      (* Cache miss - load the module *)
      let file_path = resolve_module_path module_name search_paths in
      (* Add to currently_loading list *)
      cache_ref :=
        { state with currently_loading = module_name :: state.currently_loading };

      let load_and_cache () =
        let module_obj_opt, result_env = load_module_from_file_with_module file_path env in

        (* Cache the module if found *)
        (match module_obj_opt with
        | Some (Object.Module { name = _; env = module_env; exports = _ }) ->
            let cache_entry =
              { module_object = (Object.lookup (module_name, result_env))
              ; module_env = module_env
              ; source_path = file_path
              ; timestamp = Time.gettimeofday ()
              }
            in
              Hashtbl.set state.cache ~key:module_name ~data:cache_entry
        | Some obj ->
            (* Not a module object, but we can still cache it *)
            let cache_entry =
              { module_object = obj
              ; module_env = env  (* Use current env as fallback *)
              ; source_path = file_path
              ; timestamp = Time.gettimeofday ()
              }
            in
              Hashtbl.set state.cache ~key:module_name ~data:cache_entry
        | None ->
            (* Module not found in file - this is OK if the file defines
               other things but no module with matching name *)
            ());

        (* Remove from currently_loading list *)
        cache_ref :=
          { !cache_ref with
            currently_loading =
              List.filter state.currently_loading ~f:(fun m -> not (string_equal m module_name))
          };

        result_env
      in
        try load_and_cache ()
        with
        | exn ->
          (* On error, remove from currently_loading list *)
          cache_ref :=
            { !cache_ref with
              currently_loading =
                List.filter (!cache_ref).currently_loading ~f:(fun m -> not (string_equal m module_name))
            };
          raise exn
;;

(** Get default module search paths.

    Returns a list of default directories where modules are searched.
    Currently includes the current directory and a standard modules directory.

    @return List of search path strings *)
let default_search_paths () =
  let current_dir = Core_unix.getcwd () in
  let modules_dir = Filename.concat current_dir "modules" in
    [ current_dir; modules_dir ]
;;
