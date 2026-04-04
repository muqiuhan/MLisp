(* packages/interpreter/test/unit/test_batch_mode.ml *)

let test_batch_mode_multiple_expressions () =
  let input = "(+ 1 2) (- 3 4)" in
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream input in
  let _ = Mlisp_lexer.Lexer.skip_leading_whitespace_and_comments stream in
  Alcotest.(check bool) "stream not exhausted after first expr" 
    false 
    (Mlisp_utils.Stream_wrapper.is_exhausted stream)

let test_is_exhausted_empty_stream () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "" in
  Alcotest.(check bool) "empty stream is exhausted" 
    true 
    (Mlisp_utils.Stream_wrapper.is_exhausted stream)

let test_is_exhausted_after_reading () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "abc" in
  Alcotest.(check bool) "fresh stream not exhausted" 
    false 
    (Mlisp_utils.Stream_wrapper.is_exhausted stream)

let test_is_exhausted_after_partial_read () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "abc" in
  let _ = Mlisp_lexer.Lexer.read_sexpr stream in
  Alcotest.(check bool) "stream exhausted after reading all chars"
    true
    (Mlisp_utils.Stream_wrapper.is_exhausted stream)

let test_is_exhausted_with_whitespace () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "42 " in
  let _ = Mlisp_lexer.Lexer.read_sexpr stream in
  Alcotest.(check bool) "stream exhausted after reading expr with trailing space"
    true
    (Mlisp_utils.Stream_wrapper.is_exhausted stream)

let test_suite = ("batch_mode", [
  Alcotest.test_case "batch mode multiple expressions" `Quick test_batch_mode_multiple_expressions;
  Alcotest.test_case "is exhausted empty stream" `Quick test_is_exhausted_empty_stream;
  Alcotest.test_case "is exhausted after reading" `Quick test_is_exhausted_after_reading;
  Alcotest.test_case "is exhausted after partial read" `Quick test_is_exhausted_after_partial_read;
  Alcotest.test_case "is exhausted with whitespace" `Quick test_is_exhausted_with_whitespace;
])

let run () = Alcotest.run "test_batch_mode" [test_suite]

let () = run ()