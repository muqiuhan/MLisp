(* Pretty reporter tests - Alcotest suite *)

open Core
open Mlp_lib

let test_format_passing_test () =
  let result = { Test_runner.passed = true; module_name = "math"; test_name = "test-add" } in
  let output = Reporter.format_result result in
  if not (String.is_substring output ~substring:"✓") then
    Alcotest.failf "Expected checkmark in output, got: %s" output

let test_format_failing_test () =
  let result = { Test_runner.passed = false; module_name = "math"; test_name = "test-fail" } in
  let output = Reporter.format_result result in
  if not (String.is_substring output ~substring:"✗") then
    Alcotest.failf "Expected X mark in output, got: %s" output

let tests =
  [
    "format passing test", `Quick, test_format_passing_test;
    "format failing test", `Quick, test_format_failing_test;
  ]
