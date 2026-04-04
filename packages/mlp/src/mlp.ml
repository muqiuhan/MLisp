(* MLisp Package Manager - CLI Entry Point *)

open Core
open Mlp_lib

let version = "0.1.0"

(* ANSI color codes *)
let _green s = sprintf "\027[32m%s\027[0m" s
let _red s = sprintf "\027[31m%s\027[0m" s
let bold s = sprintf "\027[1m%s\027[0m" s
let dim s = sprintf "\027[2m%s\027[0m" s

(* Find mlisp interpreter and stdlib path *)
let find_mlisp_and_stdlib () =
  (* Check if a path is a valid directory containing core.mlisp *)
  let is_valid_stdlib path =
    match Sys_unix.is_directory path with
    | `Yes ->
      let core_file = Filename.concat path "core.mlisp" in
      (match Sys_unix.is_file core_file with
       | `Yes -> true
       | `No | `Unknown -> false)
    | `No | `Unknown -> false
  in

  (* Try to find stdlib relative to a given mlisp path *)
  let find_stdlib_relative mlisp_path =
    let mlisp_dir = Filename.dirname mlisp_path in
    let stdlib_candidates = [
      (* Relative to mlisp in opam *)
      Filename.concat mlisp_dir "stdlib";
      Filename.concat mlisp_dir "../stdlib";
      (* Source tree when using dune exec *)
      Filename.concat mlisp_dir "../../../interpreter/stdlib";
      (* System-wide opam *)
      Filename.concat mlisp_dir "../../lib/mlisp/stdlib";
    ] in
    List.find stdlib_candidates ~f:is_valid_stdlib
  in

  (* Check environment variable first *)
  match Sys.getenv "MLISP_STDLIB_PATH" with
  | Some env_path ->
    if is_valid_stdlib env_path then
      (* Find mlisp in PATH *)
      let mlisp_path =
        match Sys.getenv "PATH" with
        | None -> "mlisp"
        | Some path ->
          let dirs = String.split path ~on:':' in
          match List.find_map dirs ~f:(fun dir ->
            let p = Filename.concat dir "mlisp" in
            match Sys_unix.is_file p with
            | `Yes -> Some p
            | `No | `Unknown -> None) with
          | Some p -> p
          | None -> "mlisp"
      in
      Ok (mlisp_path, env_path)
    else
      Error (sprintf
        "MLISP_STDLIB_PATH is set to \"%s\" but directory does not exist or is missing core.mlisp.\n\
         Please set a valid path or unset MLISP_STDLIB_PATH to use auto-detection."
        env_path)

  | None ->
    (* Try PATH-based mlisp with relative stdlib *)
    (match Sys.getenv "PATH" with
     | Some path ->
       let dirs = String.split path ~on:':' in
       (match List.find_map dirs ~f:(fun dir ->
         let mlisp_path = Filename.concat dir "mlisp" in
         match Sys_unix.is_file mlisp_path with
         | `Yes ->
           (match find_stdlib_relative mlisp_path with
            | Some stdlib -> Some (mlisp_path, stdlib)
            | None -> None)
         | `No | `Unknown -> None) with
        | Some (mlisp_path, stdlib_path) ->
          Ok (mlisp_path, stdlib_path)
        | None ->
          (* PATH search failed, try workspace candidates *)
          let rec try_workspace_candidates candidates =
            match candidates with
            | [] ->
              Error ("Cannot find standard library in any of the expected locations.\n\
                      Please set MLISP_STDLIB_PATH environment variable to point to your stdlib directory.")
            | (mlisp_path, stdlib_path) :: rest ->
              (match Sys_unix.is_file mlisp_path, is_valid_stdlib stdlib_path with
               | `Yes, true -> Ok (mlisp_path, stdlib_path)
               | _, _ -> try_workspace_candidates rest)
          in
          let cwd = Sys_unix.getcwd () in
          let workspace_candidates = [
            (* Dune-built mlisp relative to mlp package (go up to packages, then to workspace) *)
            (Filename.concat cwd "../interpreter/_build/default/bin/mlisp.exe",
             Filename.concat cwd "../interpreter/stdlib");
          ] in
          try_workspace_candidates workspace_candidates)
     | None ->
       (* No PATH, try workspace candidates *)
       let rec try_workspace_candidates candidates =
         match candidates with
         | [] ->
           Error "Cannot find mlisp interpreter. Please ensure mlisp is installed or run from the mlisp workspace."
         | (mlisp_path, stdlib_path) :: rest ->
           (match Sys_unix.is_file mlisp_path, is_valid_stdlib stdlib_path with
            | `Yes, true -> Ok (mlisp_path, stdlib_path)
            | _, _ -> try_workspace_candidates rest)
       in
       let cwd = Sys_unix.getcwd () in
       let workspace_candidates = [
         (* Dune-built mlisp in workspace *)
         (Filename.concat cwd "../interpreter/_build/default/bin/mlisp.exe",
          Filename.concat cwd "../interpreter/stdlib");
       ] in
       try_workspace_candidates workspace_candidates)

(* Print version information *)
let print_version () =
  printf "mlp v%s - MLisp Package Manager\n" version

(* Print help information *)
let print_help () =
  printf "mlp v%s - MLisp Package Manager\n\n" version;
  printf "%s\n" (bold "Usage:");
  printf "  mlp [OPTIONS] [COMMAND]\n\n";
  printf "%s\n" (bold "Commands:");
  printf "  %-12s %s\n" "init" "Initialize a new MLisp package";
  printf "  %-12s %s\n" "install" "Install package dependencies";
  printf "  %-12s %s\n" "test" "Run tests";
  printf "  %-12s %s\n" "build" "Build the package\n";
  printf "%s\n" (bold "Options:");
  printf "  %-12s %s\n" "-v, --version" "Print version";
  printf "  %-12s %s\n" "-h, --help" "Print help\n"

(* Package initialization template *)
let init_package name =
  sprintf
    {|
;; Package: %s
;; MLisp package configuration

(define package-name "%s")
(define package-version "0.1.0")
(define package-description "A MLisp package")

;; Dependencies: list of (name constraint) pairs
(define dependencies (list))

;; Build configuration
(define build-config
  (list))

;; Test configuration
(define test-config
  (list "test/*.mlisp"))

(export package-name package-version package-description dependencies)
|}
    name name

(* Create package directory structure *)
let create_package_structure () =
  let dirs = ["src"; "test"; "modules"] in
  let create_dir d =
    match Core_unix.mkdir_p d with
    | () -> printf "  Created: %s/\n" d
    | exception e ->
      eprintf "  Error creating %s/: %s\n" d (Exn.to_string e)
  in
  List.iter dirs ~f:create_dir

(* Run package initialization *)
let run_init name =
  printf "Initializing MLisp package: %s\n" name;
  printf "Creating directory structure...\n";
  create_package_structure ();
  let pkg_file = "package.mlisp" in
  printf "Creating %s...\n" pkg_file;
  Out_channel.write_all pkg_file ~data:(init_package name);
  printf "\nDone! Package '%s' is ready.\n" name;
  printf "Run 'mlp install' to install dependencies.\n";
  printf "Run 'mlp test' to run tests.\n"

let run_cli () =
  let version_flag = ref false in
  let help_flag = ref false in
  let spec =
    [
      ("--version", Arg.Set version_flag, "Print version");
      ("--help", Arg.Set help_flag, "Print help");
    ]
  in
  let anon_args = ref [] in
  Arg.parse spec (fun arg -> anon_args := arg :: !anon_args) "";
  let anon_list = List.rev !anon_args in
  
  if !version_flag then
    print_version ()
  else if !help_flag then
    print_help ()
  else
    match anon_list with
    | [] ->
      print_endline "Run 'mlp --help' for usage information"
    | cmd :: args ->
      match (cmd, args) with
      | ("install", []) ->
        printf "Usage: mlp install <path>\n";
        printf "  Install a package from a local path\n";
        exit 1
      | ("install", [path]) ->
        (match Installer.install_local path with
        | Ok _dest -> ()
        | Error e -> eprintf "Error: %s\n" (Error.to_string_hum e))
      | ("test", []) ->
        (* Run tests *)
        (match find_mlisp_and_stdlib () with
         | Error msg ->
           eprintf "Error: %s\n" msg;
           exit 1
         | Ok (mlisp, stdlib_path) ->
           let test_dir = "test" in
           let results = Test_runner.run_tests mlisp test_dir stdlib_path in
           (* Check for errors during test execution *)
           let errors = Test_runner.get_errors () in
           if not (List.is_empty errors) then
             begin
               eprintf "\n%s\n" (_red "ERRORS during test execution:");
               List.iter errors ~f:(fun err ->
                 eprintf "  %s: %s\n" (_red err.Test_runner.file_path) (_red err.Test_runner.error_message)
               );
               eprintf "\n%s\n" (_red "Tests failed due to execution errors");
               exit 1
             end;
           if List.is_empty results then
             printf "  %s\n" (dim "No test files found in test/ directory")
           else
             Reporter.full_report results)
      | ("build", []) ->
        print_endline "mlp build: build package"
      | ("init", []) ->
        printf "Enter package name: ";
        let name = String.strip (In_channel.input_line In_channel.stdin |> Option.value ~default:"my-package") in
        run_init name
      | ("init", [name]) ->
        run_init name
      | (c, _) ->
        eprintf "Unknown command: %s\n" c;
        exit 1

let () = run_cli ()
