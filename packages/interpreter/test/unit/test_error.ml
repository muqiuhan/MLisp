(* packages/interpreter/test/unit/test_error.ml *)

let test_result_bind () =
  let result = Mlisp_error.Result.(Ok 42 >>= fun x -> return (x + 1)) in
  match result with
  | Ok v -> Alcotest.(check int) "bind works" 43 v
  | Error _ -> Alcotest.fail "expected Ok"

let test_result_map () =
  let result = Mlisp_error.Result.(Ok 42 >>| succ) in
  match result with
  | Ok v -> Alcotest.(check int) "map works" 43 v
  | Error _ -> Alcotest.fail "expected Ok"

let test_result_fail () =
  let result = Mlisp_error.Result.(Error (Failure "test") >>= fun _ -> fail (Failure "should not reach")) in
  match result with
  | Ok _ -> Alcotest.fail "expected Error"
  | Error e -> Alcotest.(check string) "error preserved" "Failure(\"test\")" (Printexc.to_string e)

let test_location () =
  let loc = Mlisp_error.Error_context.make_location ~line:10 ~column:5 ~file:"test.ml" () in
  Alcotest.(check int) "line" 10 loc.Mlisp_error.Error_context.line;
  Alcotest.(check int) "column" 5 loc.Mlisp_error.Error_context.column;
  Alcotest.(check string) "file" "test.ml" loc.Mlisp_error.Error_context.file

let test_error_context () =
  let loc = Mlisp_error.Error_context.make_location ~line:1 ~column:1 ~file:"test.ml" () in
  let ctx = Mlisp_error.Error_context.make ~location:loc ~message:"test error" ~hints:["hint1"; "hint2"] () in
  Alcotest.(check string) "message" "test error" ctx.Mlisp_error.Error_context.message;
  Alcotest.(check int) "hint count" 2 (List.length ctx.Mlisp_error.Error_context.hints)

let test_located_error () =
  let loc = Mlisp_error.Error_context.make_location ~line:5 ~column:10 ~file:"test.ml" () in
  let err = Mlisp_error.Errors.Located_error {
    location = loc;
    error = Mlisp_error.Errors.Not_found "x";
    context = ["in let binding"; "in module test"]
  } in
  match err with
  | Mlisp_error.Errors.Located_error { location; error; context } ->
    Alcotest.(check int) "line" 5 location.Mlisp_error.Error_context.line;
    Alcotest.(check string) "not_found" "x" (match error with Mlisp_error.Errors.Not_found s -> s | _ -> "");
    Alcotest.(check int) "context len" 2 (List.length context)
  | _ -> Alcotest.fail "expected Located_error"

(* Test the located_error helper function from errors.ml *)
let test_located_error_helper () =
  let loc = Mlisp_error.Error_context.make_location ~line:3 ~column:7 ~file:"test.ml" () in
  let err = Mlisp_error.Errors.located_error
    ~location:loc
    ~error:(Mlisp_error.Errors.Not_found "y")
    ~context:["in lambda"]
    ()
  in
  match err with
  | Mlisp_error.Errors.Located_error { location; error; context } ->
    Alcotest.(check int) "line" 3 location.Mlisp_error.Error_context.line;
    Alcotest.(check string) "not_found" "y" (match error with Mlisp_error.Errors.Not_found s -> s | _ -> "");
    Alcotest.(check int) "context len" 1 (List.length context)
  | _ -> Alcotest.fail "expected Located_error"

(* Test located_error with default empty context *)
let test_located_error_default_context () =
  let loc = Mlisp_error.Error_context.make_location ~line:1 ~column:1 ~file:"test.ml" () in
  let err = Mlisp_error.Errors.located_error
    ~location:loc
    ~error:(Mlisp_error.Errors.Value_error ("x", "expected number"))
    ()
  in
  match err with
  | Mlisp_error.Errors.Located_error { location = _; error; context } ->
    Alcotest.(check int) "context empty" 0 (List.length context);
    (match error with
     | Mlisp_error.Errors.Value_error (name, msg) ->
       Alcotest.(check string) "value_error name" "x" name;
       Alcotest.(check string) "value_error msg" "expected number" msg
     | _ -> Alcotest.fail "expected Value_error")
  | _ -> Alcotest.fail "expected Located_error"

let test_suite = [
  ("error_result", [
     Alcotest.test_case "result bind" `Quick test_result_bind;
     Alcotest.test_case "result map" `Quick test_result_map;
     Alcotest.test_case "result fail" `Quick test_result_fail;
   ]);
  ("error_context", [
       Alcotest.test_case "location" `Quick test_location;
       Alcotest.test_case "error_context" `Quick test_error_context;
       Alcotest.test_case "located_error" `Quick test_located_error;
       Alcotest.test_case "located_error_helper" `Quick test_located_error_helper;
       Alcotest.test_case "located_error_default_context" `Quick test_located_error_default_context;
     ])
]

let run () = Alcotest.run "test_error" test_suite

let () = run ()