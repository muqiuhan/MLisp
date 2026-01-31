(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_error
open Mlisp_object
open Core
open Core_unix

(** Find the standard library directory.
    
    Searches for the stdlib directory in the following order:
    1. Environment variable MLISP_STDLIB_PATH
    2. Relative to current working directory: ./stdlib
    3. Relative to executable: ../stdlib (for installed binaries)
    4. Relative to executable: ./stdlib (for development builds)
    
    @return Path to stdlib directory
    @raise Errors.Runtime_error_exn if stdlib directory not found *)
let find_stdlib_dir () =
  let check_dir path =
    let core_file = Filename.concat path "core.mlisp" in
      match access core_file [ `Exists ] with
      | Ok () ->
        Some path
      | Error _ ->
        None
  in
  (* Check environment variable first *)
  let env_path_opt = Sys.getenv "MLISP_STDLIB_PATH" in
    match env_path_opt with
    | Some env_path -> (
      match check_dir env_path with
      | Some path ->
        path
      | None ->
        raise
          (Errors.Runtime_error_exn
             (Errors.Module_load_error
                ( env_path
                , [%string
                    "Standard library directory not found at '%{env_path}'. core.mlisp \
                     file is missing."] ))))
    | None -> (
      (* Check relative to current directory *)
      match check_dir "stdlib" with
      | Some path ->
        path
      | None -> (
        (* Check relative to executable *)
        let exec_dir =
          try Filename.dirname Sys_unix.executable_name with
          | _ ->
            Filename.current_dir_name
        in
        let candidate_paths =
          [ Filename.concat exec_dir "stdlib"
          ; Filename.concat (Filename.dirname exec_dir) "stdlib"
          ; Filename.concat exec_dir "../stdlib"
          ]
        in
          match List.find_map candidate_paths ~f:check_dir with
          | Some path ->
            path
          | None ->
            let searched_paths = String.concat ~sep:", " ("stdlib" :: candidate_paths) in
              raise
                (Errors.Runtime_error_exn
                   (Errors.Module_load_error
                      ( "stdlib"
                      , [%string
                          "Standard library directory not found. Searched in: \
                           %{searched_paths}. Please ensure stdlib directory exists and \
                           contains core.mlisp."] )))))
;;

(** Load and parse metadata from _meta.mlisp file.
    
    Loads the metadata file and extracts version and module list.
    
    @param stdlib_dir Path to stdlib directory
    @param env Initial environment
    @return Tuple of (version, modules list, updated environment)
    @raise Errors.Runtime_error_exn if metadata cannot be loaded *)
let load_metadata stdlib_dir env =
  let meta_file = Filename.concat stdlib_dir "_meta.mlisp" in
  let meta_env =
    try Mlisp_module_loader.Module_loader.load_module_from_file meta_file env with
    | _ ->
      (* If _meta.mlisp doesn't exist, use defaults *)
      env
  in
  let get_string_value name default =
    try
      match Object.lookup (name, meta_env) with
      | Object.String s ->
        s
      | _ ->
        default
    with
    | _ ->
      default
  in
  let get_list_value name default =
    try
      match Object.lookup (name, meta_env) with
      | Object.Pair _ as list_obj ->
        let rec extract_strings acc = function
          | Object.Nil ->
            List.rev acc
          | Object.Pair (Object.String s, rest) ->
            extract_strings (s :: acc) rest
          | Object.Pair (_, rest) ->
            extract_strings acc rest
          | _ ->
            default
        in
          extract_strings [] list_obj
      | _ ->
        default
    with
    | _ ->
      default
  in
  let version = get_string_value "stdlib-version" "unknown" in
  let modules = get_list_value "stdlib-modules" [ "core"; "list"; "io"; "assert" ] in
    version, modules, meta_env
;;

(** Load standard library from files.
    
    Loads standard library modules from .mlisp files.
    First loads metadata to get version and module list, then loads all modules.
    
    @param env Initial environment (basis)
    @return Environment with standard library loaded
    @raise Errors.Runtime_error_exn if loading fails *)
let load_stdlib_from_files env =
  let stdlib_dir = find_stdlib_dir () in
  let version, modules, env_with_meta = load_metadata stdlib_dir env in
  let loaded_env =
    List.fold_left modules ~init:env_with_meta ~f:(fun env module_name ->
      let module_file = Filename.concat stdlib_dir (module_name ^ ".mlisp") in
        Mlisp_module_loader.Module_loader.load_module_from_file module_file env)
  in
    version, modules, loaded_env
;;

(** Initialize standard library environment.
    
    Loads standard library from .mlisp files in the stdlib directory.
    First loads metadata to display version and module information.
    Raises an error if the stdlib directory or any required module file
    is not found.
    
    @return Environment with standard library loaded
    @raise Errors.Runtime_error_exn if stdlib files cannot be loaded *)
let stdlib_core =
  let env = Mlisp_primitives.Basis.basis in
  let version, modules, loaded_env = load_stdlib_from_files env in
  let modules_str = String.concat ~sep:", " modules in
    print_endline (Format.sprintf "o- Loading standard library v%s..." version);
    print_endline (Format.sprintf "o- Loaded modules: %s" modules_str);
    loaded_env
;;
