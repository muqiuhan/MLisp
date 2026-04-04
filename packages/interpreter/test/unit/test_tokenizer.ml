(* packages/interpreter/test/unit/test_tokenizer.ml *)
open Core

let test_tokenize_number () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "42 " in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized number" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) (Mlisp_lexer.Token.T_Number 42))
  | Error e -> Alcotest.fail ("error: " ^ Mlisp_lexer.Lexer_error.format_error e)

let test_tokenize_symbol () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "hello " in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized symbol" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) (Mlisp_lexer.Token.T_Symbol "hello"))
  | Error e -> Alcotest.fail ("error: " ^ Mlisp_lexer.Lexer_error.format_error e)

let test_tokenize_string_with_escape () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "\"hello\\nworld\"" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> (
    match Mlisp_lexer.Token.kind tok with
    | Mlisp_lexer.Token.T_String s -> Alcotest.(check string) "string" "hello\nworld" s
    | _ -> Alcotest.fail "expected T_String"
  )
  | Error e -> Alcotest.fail ("error: " ^ Mlisp_lexer.Lexer_error.format_error e)

let test_tokenize_lparen () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "(" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized lparen" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) Mlisp_lexer.Token.T_Lparen)
  | Error _ -> Alcotest.fail "expected T_Lparen"

let test_tokenize_rparen () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream ")" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized rparen" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) Mlisp_lexer.Token.T_Rparen)
  | Error _ -> Alcotest.fail "expected T_Rparen"

let test_tokenize_quote () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "'" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized quote" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) Mlisp_lexer.Token.T_Quote)
  | Error _ -> Alcotest.fail "expected T_Quote"

let test_tokenize_backquote () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "`" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized backquote" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) Mlisp_lexer.Token.T_Backquote)
  | Error _ -> Alcotest.fail "expected T_Backquote"

let test_tokenize_comma () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "," in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized comma" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) Mlisp_lexer.Token.T_Comma)
  | Error _ -> Alcotest.fail "expected T_Comma"

let test_tokenize_comma_at () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream ",@" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized comma-at" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) Mlisp_lexer.Token.T_CommaAt)
  | Error _ -> Alcotest.fail "expected T_CommaAt"

let test_tokenize_boolean_true () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "#t" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized #t" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) (Mlisp_lexer.Token.T_Boolean true))
  | Error _ -> Alcotest.fail "expected T_Boolean true"

let test_tokenize_boolean_false () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "#f" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized #f" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) (Mlisp_lexer.Token.T_Boolean false))
  | Error _ -> Alcotest.fail "expected T_Boolean false"

let test_tokenize_string () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "\"hello\"" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized string" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) (Mlisp_lexer.Token.T_String "hello"))
  | Error _ -> Alcotest.fail "expected T_String"

let test_tokenize_negative_number () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "-42" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized negative number" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) (Mlisp_lexer.Token.T_Number (-42)))
  | Error _ -> Alcotest.fail "expected T_Number -42"

let test_tokenize_whitespace_skip () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "   42" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "skipped whitespace" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) (Mlisp_lexer.Token.T_Number 42))
  | Error _ -> Alcotest.fail "expected T_Number after whitespace"

let test_tokenize_comment_skip () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "; comment\n42" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "skipped comment" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) (Mlisp_lexer.Token.T_Number 42))
  | Error _ -> Alcotest.fail "expected T_Number after comment"

let test_tokenize_eof () =
  let stream = Mlisp_utils.Stream_wrapper.make_stringstream "" in
  let tokenizer = Mlisp_lexer.Tokenizer.create stream in
  match Mlisp_lexer.Tokenizer.next tokenizer with
  | Ok tok -> Alcotest.(check bool) "tokenized EOF" true (Mlisp_lexer.Token.equal_kind (Mlisp_lexer.Token.kind tok) Mlisp_lexer.Token.T_EOF)
  | Error _ -> Alcotest.fail "expected T_EOF"

let test_suite = [
  ("tokenize_number", [
     Alcotest.test_case "tokenizes number" `Quick test_tokenize_number;
    ]);
  ("tokenize_symbol", [
     Alcotest.test_case "tokenizes symbol" `Quick test_tokenize_symbol;
    ]);
  ("tokenize_string", [
     Alcotest.test_case "tokenizes string" `Quick test_tokenize_string;
     Alcotest.test_case "tokenizes string with escape" `Quick test_tokenize_string_with_escape;
    ]);
  ("tokenize_lparen", [
     Alcotest.test_case "tokenizes lparen" `Quick test_tokenize_lparen;
    ]);
  ("tokenize_rparen", [
     Alcotest.test_case "tokenizes rparen" `Quick test_tokenize_rparen;
    ]);
  ("tokenize_quote", [
     Alcotest.test_case "tokenizes quote" `Quick test_tokenize_quote;
    ]);
  ("tokenize_backquote", [
     Alcotest.test_case "tokenizes backquote" `Quick test_tokenize_backquote;
    ]);
  ("tokenize_comma", [
     Alcotest.test_case "tokenizes comma" `Quick test_tokenize_comma;
     Alcotest.test_case "tokenizes comma-at" `Quick test_tokenize_comma_at;
    ]);
  ("tokenize_boolean", [
     Alcotest.test_case "tokenizes #t" `Quick test_tokenize_boolean_true;
     Alcotest.test_case "tokenizes #f" `Quick test_tokenize_boolean_false;
    ]);
  ("tokenize_negative", [
     Alcotest.test_case "tokenizes negative number" `Quick test_tokenize_negative_number;
    ]);
  ("tokenize_whitespace", [
     Alcotest.test_case "skips whitespace" `Quick test_tokenize_whitespace_skip;
     Alcotest.test_case "skips comment" `Quick test_tokenize_comment_skip;
    ]);
  ("tokenize_eof", [
     Alcotest.test_case "tokenizes EOF" `Quick test_tokenize_eof;
    ]);
]

let run () = Alcotest.run "test_tokenizer" test_suite

let () = run ()