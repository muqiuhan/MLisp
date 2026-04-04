(* packages/interpreter/test/unit/test_closure.ml *)
open Mlisp_object_closure

let test_analyze_free_vars_simple () =
  let expr = Var "x" in
  let free = analyze_free_vars expr ["y"] in
  Alcotest.(check (list string)) "free vars" ["x"] free

let test_analyze_free_vars_nested () =
  let expr = Lambda ("f", ["x"], Var "y") in
  let free = analyze_free_vars expr ["f"; "x"] in
  Alcotest.(check (list string)) "free vars" ["y"] free

let test_create_closure_env () =
  let env = create_env () in
  let env' = bind ("x", Fixnum 10, env) in
  let closure_env = create_closure_env ["x"] env' in
  Alcotest.(check int) "captured count" 1 (List.length closure_env.captured_vars)

let test_suite = [
  ("closure", [
      Alcotest.test_case "analyze_free_vars_simple" `Quick test_analyze_free_vars_simple;
      Alcotest.test_case "analyze_free_vars_nested" `Quick test_analyze_free_vars_nested;
      Alcotest.test_case "create_closure_env" `Quick test_create_closure_env;
    ])
]

let run () = Alcotest.run "test_closure" test_suite

let () = run ()