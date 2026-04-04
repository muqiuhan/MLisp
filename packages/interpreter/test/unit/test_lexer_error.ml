(* packages/interpreter/test/unit/test_lexer_error.ml *)

let string_contains ~(haystack : string) ~(needle : string) : bool =
  let needle_len = String.length needle in
  let rec search i =
    if i > String.length haystack - needle_len then false
    else if String.sub haystack i needle_len = needle then true
    else search (i + 1)
  in
  search 0

let test_unexpected_char_error () =
  let loc = Mlisp_lexer.Location.make ~line:5 ~column:10 ~offset:50 ~file:"test.ml" in
  let err = Mlisp_lexer.Lexer_error.Unexpected_char { found='@'; location=loc; expected=Some "digit or symbol" } in
  let formatted = Mlisp_lexer.Lexer_error.format_error err in
  Alcotest.(check bool) "contains @" true (string_contains ~haystack:formatted ~needle:"@")

let test_unterminated_string_error () =
  let loc = Mlisp_lexer.Location.make ~line:1 ~column:1 ~offset:0 ~file:"test.ml" in
  let err = Mlisp_lexer.Lexer_error.Unterminated_string { location=loc; start_loc=loc } in
  let formatted = Mlisp_lexer.Lexer_error.format_error err in
  Alcotest.(check bool) "contains unterminated" true (string_contains ~haystack:formatted ~needle:"unterminated")

let test_invalid_escape_error () =
  let loc = Mlisp_lexer.Location.make ~line:1 ~column:5 ~offset:10 ~file:"test.ml" in
  let err = Mlisp_lexer.Lexer_error.Invalid_escape { escape='x'; location=loc } in
  let formatted = Mlisp_lexer.Lexer_error.format_error err in
  Alcotest.(check bool) "contains invalid escape" true (string_contains ~haystack:formatted ~needle:"invalid escape")

let test_invalid_number_error () =
  let loc = Mlisp_lexer.Location.make ~line:2 ~column:0 ~offset:20 ~file:"test.ml" in
  let err = Mlisp_lexer.Lexer_error.Invalid_number { text="12a"; location=loc } in
  let formatted = Mlisp_lexer.Lexer_error.format_error err in
  Alcotest.(check bool) "contains invalid number" true (string_contains ~haystack:formatted ~needle:"invalid number")

let test_invalid_float_error () =
  let loc = Mlisp_lexer.Location.make ~line:3 ~column:0 ~offset:30 ~file:"test.ml" in
  let err = Mlisp_lexer.Lexer_error.Invalid_float { text="1.2.3"; location=loc } in
  let formatted = Mlisp_lexer.Lexer_error.format_error err in
  Alcotest.(check bool) "contains invalid float" true (string_contains ~haystack:formatted ~needle:"invalid float")

let test_suite = [
  ("unexpected_char_error", [
     Alcotest.test_case "contains found char" `Quick test_unexpected_char_error;
    ]);
  ("unterminated_string_error", [
     Alcotest.test_case "contains unterminated" `Quick test_unterminated_string_error;
    ]);
  ("invalid_escape_error", [
     Alcotest.test_case "contains invalid escape" `Quick test_invalid_escape_error;
    ]);
  ("invalid_number_error", [
     Alcotest.test_case "contains invalid number" `Quick test_invalid_number_error;
    ]);
  ("invalid_float_error", [
     Alcotest.test_case "contains invalid float" `Quick test_invalid_float_error;
    ]);
]

let run () = Alcotest.run "test_lexer_error" test_suite

let () = run ()