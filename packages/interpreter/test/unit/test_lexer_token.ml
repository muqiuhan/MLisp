(* packages/interpreter/test/unit/test_lexer_token.ml *)

let test_token_kind_eq () =
  Alcotest.(check bool) "lparen eq" true (Mlisp_lexer.Token.equal_kind Mlisp_lexer.Token.T_Lparen Mlisp_lexer.Token.T_Lparen);
  Alcotest.(check bool) "lparen neq" false (Mlisp_lexer.Token.equal_kind Mlisp_lexer.Token.T_Lparen Mlisp_lexer.Token.T_Rparen)

let test_token_accessors () =
  let tok = Mlisp_lexer.Token.make (Mlisp_lexer.Token.T_Number 42) ~loc:(Mlisp_lexer.Location.make ~line:1 ~column:1 ~offset:0 ~file:"t.ml") ~text:"42" in
  Alcotest.(check string) "text" "42" (Mlisp_lexer.Token.text tok);
  Alcotest.(check string) "file" "t.ml" ((Mlisp_lexer.Token.loc tok).Mlisp_lexer.Location.file)

let test_suite = [
  ("token_kind_eq", [
     Alcotest.test_case "lparen eq" `Quick test_token_kind_eq;
    ]);
  ("token_accessors", [
     Alcotest.test_case "accessors" `Quick test_token_accessors;
    ]);
]

let run () = Alcotest.run "test_lexer_token" test_suite

let () = run ()
