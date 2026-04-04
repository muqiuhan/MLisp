(* Test runner functionality - Alcotest suite *)

open Mlp_lib

let test_parse_test_result_pass () =
  let sexp = Sexplib.Sexp.of_string "(TEST_RESULT true mytest)" in
  match Test_runner.parse_test_result sexp with
  | Some { passed = true; test_name = "mytest"; _ } -> ()
  | Some r ->
    Alcotest.failf "Expected passed=true, got passed=%b" r.Test_runner.passed
  | None ->
    Alcotest.fail "Failed to parse TEST_RESULT"

let test_parse_test_result_fail () =
  let sexp = Sexplib.Sexp.of_string "(TEST_RESULT false mytest)" in
  match Test_runner.parse_test_result sexp with
  | Some { passed = false; test_name = "mytest"; _ } -> ()
  | Some r ->
    Alcotest.failf "Expected passed=false, got passed=%b" r.Test_runner.passed
  | None ->
    Alcotest.fail "Failed to parse TEST_RESULT"

let test_parse_module_start () =
  let sexp = Sexplib.Sexp.of_string "(MODULE_START math)" in
  match Test_runner.parse_module_start sexp with
  | Some "math" -> ()
  | Some s ->
    Alcotest.failf "Expected module 'math', got '%s'" s
  | None ->
    Alcotest.fail "Failed to parse MODULE_START"

let tests =
  [
    "parse TEST_RESULT (pass)", `Quick, test_parse_test_result_pass;
    "parse TEST_RESULT (fail)", `Quick, test_parse_test_result_fail;
    "parse MODULE_START", `Quick, test_parse_module_start;
  ]
