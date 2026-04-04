(* Test Runner - Simple scan + run + parse *)

open Core
open Sexplib.Sexp

(** Test result from execution *)
type test_result = {
  module_name : string;
  test_name : string;
  passed : bool;
}

(** Error from test file execution *)
type test_error = {
  file_path : string;
  error_message : string;
}

(** Global error storage - populated during test run *)
let test_errors : test_error list ref = ref []

(** Parse a TEST_RESULT line: (TEST_RESULT true "name") *)
let parse_test_result sexp =
  match sexp with
  | List [Atom "TEST_RESULT"; Atom passed_str; Atom name] ->
    let passed_bool = String.equal passed_str "true" in
    Some { module_name = ""; test_name = name; passed = passed_bool }
  | _ -> None

(** Parse a MODULE_START line: (MODULE_START math) *)
let parse_module_start sexp =
  match sexp with
  | List [Atom "MODULE_START"; Atom name] -> Some name
  | _ -> None

(** Check if a line contains an error marker *)
let is_error_line line =
  (* Strip ANSI escape codes for comparison using Str *)
  let clean_line = 
    Str.global_replace (Str.regexp "\027\\[[0-9;]*m") "" line
  in
  let lower_line = String.lowercase clean_line in
  (* Check for common error patterns in mlisp output *)
  String.is_substring lower_line ~substring:"error" ||
  String.is_substring lower_line ~substring:"uncaught exception" ||
  String.is_substring lower_line ~substring:"failed to" ||
  String.is_substring lower_line ~substring:"not found"

(** Run mlisp and capture output (both stdout and stderr) *)
let run_mlisp mlisp_path file_path stdlib_path =
  (* Run in the directory containing the file *)
  let dir = Filename.dirname file_path in
  let basename = Filename.basename file_path in
  (* Build command: cd dir && MLISP_STDLIB_PATH=path mlisp file *)
  (* Use 2>&1 to redirect stderr to stdout *)
  let cmd = sprintf "cd %s && MLISP_STDLIB_PATH=%s %s %s 2>&1" dir stdlib_path mlisp_path basename in
  Core_unix.open_process_in cmd |> In_channel.input_all

(** Run a single test file and return results *)
let run_test_file mlisp_path file_path stdlib_path =
  let output = run_mlisp mlisp_path file_path stdlib_path in
  let lines = String.split_lines output in

  (* Separate error lines from sexp lines *)
  let error_lines, sexp_lines =
    List.partition_tf lines ~f:is_error_line 
  in

  (* Parse S-expressions *)
  let sexps = List.filter_map sexp_lines ~f:(fun line ->
    try Some (Sexp.of_string line) with _ -> None
  ) in

  (* Parse test results *)
  let results = ref [] in
  let current_module = ref "" in
  List.iter sexps ~f:(fun sexp ->
    match parse_module_start sexp with
    | Some name -> current_module := name
    | None ->
      (match parse_test_result sexp with
       | Some r -> results := { r with module_name = !current_module } :: !results
       | None -> ())
  );

  (* Collect errors *)
  let errors = List.map error_lines ~f:(fun msg ->
    { file_path = file_path; error_message = msg }
  ) in

  (List.rev !results, errors)

(** Scan directory for test files *)
let find_test_files dir =
  try
    let _ = Core_unix.access dir [`Read] in
    let entries = Array.to_list (Stdlib.Sys.readdir dir) in
    List.filter entries ~f:(fun f -> String.is_suffix f ~suffix:".mlisp")
    |> List.map ~f:(Filename.concat dir)
  with _ -> []

(** Run all tests in a directory *)
let run_tests mlisp_path test_dir stdlib_path =
  let files = find_test_files test_dir in
  test_errors := [];  (* Reset errors *)
  let all_results, all_errors =
    List.fold files ~init:([], []) ~f:(fun (results, errors) file ->
      let file_results, file_errors = run_test_file mlisp_path file stdlib_path in
      (file_results @ results, file_errors @ errors)
    )
  in
  test_errors := all_errors;
  List.rev all_results

(** Get collected errors *)
let get_errors () = !test_errors
