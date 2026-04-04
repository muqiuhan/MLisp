(* packages/interpreter/test/unit/test_environment.ml *)
open Mlisp_object

let test_create_env () =
  let env = Environment.create_env () in
  Alcotest.(check int) "level 0" 0 env.level;
  Alcotest.(check bool) "no parent" true (Option.is_none env.parent)

let test_bind_and_lookup () =
  let env = Environment.create_env () in
  let env' = Environment.bind ("x", Fixnum 42, env) in
  match Environment.lookup ("x", env') with
  | Ok (Fixnum n) -> Alcotest.(check int) "lookup x" 42 n
  | Ok _ -> Alcotest.fail "wrong type"
  | Error _ -> Alcotest.fail "lookup failed"

let test_lookup_not_found () =
  let env = Environment.create_env () in
  match Environment.lookup ("nonexistent", env) with
  | Ok _ -> Alcotest.fail "should be error"
  | Error (Mlisp_error.Errors.Not_found name) -> Alcotest.(check string) "not found" "nonexistent" name
  | Error _ -> Alcotest.fail "wrong error type"

let test_extend_env () =
  let env = Environment.create_env () in
  let child = Environment.extend_env env in
  Alcotest.(check int) "child level" 1 child.level;
  Alcotest.(check bool) "has parent" true (Option.is_some child.parent)

let test_suite = [
  ("environment", [
      Alcotest.test_case "create_env" `Quick test_create_env;
      Alcotest.test_case "bind_and_lookup" `Quick test_bind_and_lookup;
      Alcotest.test_case "lookup_not_found" `Quick test_lookup_not_found;
      Alcotest.test_case "extend_env" `Quick test_extend_env;
    ])
]

let run () = Alcotest.run "test_environment" test_suite

let () = run ()