(* packages/interpreter/test/unit/test_lexer_location.ml *)

let test_location_basic () =
  let loc = Mlisp_lexer.Location.make ~line:10 ~column:5 ~offset:100 ~file:"test.ml" in
  Alcotest.(check int) "line" 10 loc.Mlisp_lexer.Location.line;
  Alcotest.(check int) "column" 5 loc.Mlisp_lexer.Location.column;
  Alcotest.(check int) "offset" 100 loc.Mlisp_lexer.Location.offset;
  Alcotest.(check string) "file" "test.ml" loc.Mlisp_lexer.Location.file

let test_location_to_string () =
  let loc = Mlisp_lexer.Location.make ~line:5 ~column:10 ~offset:50 ~file:"main.mlisp" in
  let s = Mlisp_lexer.Location.to_string loc in
  Alcotest.(check string) "formatted" "main.mlisp:5:10" s

let test_location_default () =
  let loc = Mlisp_lexer.Location.make_default ~file:"default.ml" () in
  Alcotest.(check int) "default line" 1 loc.Mlisp_lexer.Location.line;
  Alcotest.(check int) "default column" 1 loc.Mlisp_lexer.Location.column;
  Alcotest.(check int) "default offset" 0 loc.Mlisp_lexer.Location.offset

let test_suite = [
  ("location", [
     Alcotest.test_case "basic" `Quick test_location_basic;
     Alcotest.test_case "to_string" `Quick test_location_to_string;
     Alcotest.test_case "default" `Quick test_location_default;
   ])
]

let run () = Alcotest.run "test_lexer_location" test_suite

let () = run ()
