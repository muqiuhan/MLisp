(** Alcotest tests for the Lexer module *)

module L = Mlisp_lexer.Lexer
module O = Mlisp_object.Object
module Stream = Mlisp_utils.Stream_wrapper

let check_lobject = Alcotest.(check (option string))
let check_string = Alcotest.(check string)
let check_bool = Alcotest.(check bool)
let check_int = Alcotest.(check int)

let rec lobject_to_sexp_string obj =
  match obj with
  | O.Fixnum n -> string_of_int n
  | O.Float f -> string_of_float f
  | O.Boolean true -> "#t"
  | O.Boolean false -> "#f"
  | O.Symbol s -> s
  | O.String s -> "\"" ^ s ^ "\""
  | O.Nil -> "nil"
  | O.Pair (car, cdr) -> "(" ^ lobject_to_sexp_string car ^ lobject_list_to_string cdr ^ ")"
  | O.Quote e -> "'" ^ lobject_to_sexp_string e
  | O.Quasiquote e -> "`" ^ lobject_to_sexp_string e
  | O.Unquote e -> "," ^ lobject_to_sexp_string e
  | O.UnquoteSplicing e -> ",@" ^ lobject_to_sexp_string e
  | O.RestParam s -> "&rest " ^ s
  | O.Primitive (name, _) -> "#<primitive:" ^ name ^ ">"
  | O.Closure (name, _, _, _) -> "#<closure:" ^ name ^ ">"
  | O.Macro (name, _, _, _) -> "#<macro:" ^ name ^ ">"
  | O.Record (name, _) -> "#<record:" ^ name ^ ">"
  | O.Module { name; _ } -> "#<module:" ^ name ^ ">"
  | O.Array arr ->
    let elems = Array.to_list arr in
    let elems_str = String.concat ", " (Stdlib.List.map lobject_to_sexp_string elems) in
      "#<array:" ^ string_of_int (Array.length arr) ^ "[" ^ elems_str ^ "]>"

and lobject_list_to_string l =
  match l with
  | O.Nil -> ""
  | O.Pair (car, cdr) -> " " ^ lobject_to_sexp_string car ^ lobject_list_to_string cdr
  | other -> " . " ^ lobject_to_sexp_string other

let make_stream s = Stream.make_stringstream s

let test_read_fixnum () =
  let stream = make_stream "42 " in
  let result = L.read_sexpr stream in
  match result with
  | O.Fixnum n -> check_int "read fixnum 42" 42 n
  | _ -> Alcotest.fail "Expected Fixnum"

let test_read_negative_fixnum () =
  let stream = make_stream "-123 " in
  let result = L.read_sexpr stream in
  match result with
  | O.Fixnum n -> check_int "read negative fixnum -123" (-123) n
  | _ -> Alcotest.fail "Expected negative Fixnum"

let test_read_float () =
  let stream = make_stream "3.14 " in
  let result = L.read_sexpr stream in
  match result with
  | O.Float f -> check_bool "read float 3.14" true (Float.abs (f -. 3.14) < 0.001)
  | _ -> Alcotest.fail "Expected Float"

let test_read_negative_float () =
  let stream = make_stream "-2.5 " in
  let result = L.read_sexpr stream in
  match result with
  | O.Float f -> check_bool "read negative float -2.5" true (Float.abs (f +. 2.5) < 0.001)
  | _ -> Alcotest.fail "Expected negative Float"

let test_read_string () =
  let stream = make_stream "\"hello\"" in
  let result = L.read_sexpr stream in
  match result with
  | O.String s -> check_string "read string \"hello\"" "hello" s
  | _ -> Alcotest.fail "Expected String"

let test_read_empty_string () =
  let stream = make_stream "\"\"" in
  let result = L.read_sexpr stream in
  match result with
  | O.String s -> check_string "read empty string" "" s
  | _ -> Alcotest.fail "Expected empty String"

let test_read_string_unterminated () =
  let stream = make_stream "\"hello" in
  let result =
    try
      let _ = L.read_sexpr stream in
      Error "Expected exception but got result"
    with
    | Mlisp_error.Errors.Syntax_error_exn _ -> Ok ()
    | e -> Error (Printexc.to_string e)
  in
  match result with
  | Ok () -> ()
  | Error msg -> Alcotest.fail msg

let test_read_symbol () =
  let stream = make_stream "foo " in
  let result = L.read_sexpr stream in
  match result with
  | O.Symbol s -> check_string "read symbol foo" "foo" s
  | _ -> Alcotest.fail "Expected Symbol"

let test_read_plus_symbol () =
  let stream = make_stream "+ " in
  let result = L.read_sexpr stream in
  match result with
  | O.Symbol s -> check_string "read symbol +" "+" s
  | _ -> Alcotest.fail "Expected Symbol +"

let test_read_minus_symbol () =
  let stream = make_stream "- " in
  let result = L.read_sexpr stream in
  match result with
  | O.Symbol s -> check_string "read symbol -" "-" s
  | _ -> Alcotest.fail "Expected Symbol -"

let test_read_boolean_true () =
  let stream = make_stream "#t" in
  let result = L.read_sexpr stream in
  match result with
  | O.Boolean b -> check_bool "read boolean #t" true b
  | _ -> Alcotest.fail "Expected Boolean true"

let test_read_boolean_false () =
  let stream = make_stream "#f" in
  let result = L.read_sexpr stream in
  match result with
  | O.Boolean b -> check_bool "read boolean #f" false b
  | _ -> Alcotest.fail "Expected Boolean false"

let test_read_quote () =
  let stream = make_stream "'x " in
  let result = L.read_sexpr stream in
  match result with
  | O.Quote e -> (match e with
    | O.Symbol s -> check_string "quote 'x" "x" s
    | _ -> Alcotest.fail "Expected quoted Symbol")
  | _ -> Alcotest.fail "Expected Quote"

let test_read_quasiquote () =
  let stream = make_stream "`x " in
  let result = L.read_sexpr stream in
  match result with
  | O.Quasiquote e -> (match e with
    | O.Symbol s -> check_string "quasiquote `x" "x" s
    | _ -> Alcotest.fail "Expected quasiquoted Symbol")
  | _ -> Alcotest.fail "Expected Quasiquote"

let test_read_unquote () =
  let stream = make_stream ",x " in
  let result = L.read_sexpr stream in
  match result with
  | O.Unquote e -> (match e with
    | O.Symbol s -> check_string "unquote ,x" "x" s
    | _ -> Alcotest.fail "Expected unquoted Symbol")
  | _ -> Alcotest.fail "Expected Unquote"

let test_read_unquote_splicing () =
  let stream = make_stream ",@x " in
  let result = L.read_sexpr stream in
  match result with
  | O.UnquoteSplicing e -> (match e with
    | O.Symbol s -> check_string "unquote-splicing ,@x" "x" s
    | _ -> Alcotest.fail "Expected unquote-splicing Symbol")
  | _ -> Alcotest.fail "Expected UnquoteSplicing"

let test_read_nil_symbol () =
  let stream = make_stream "nil " in
  let result = L.read_sexpr stream in
  match result with
  | O.Symbol s -> check_string "read nil symbol" "nil" s
  | _ -> Alcotest.fail "Expected Symbol nil"

let test_read_empty_list () =
  let stream = make_stream "() " in
  let result = L.read_sexpr stream in
  match result with
  | O.Nil -> check_bool "read empty list" true true
  | _ -> Alcotest.fail "Expected empty list (Nil)"

let test_read_simple_list () =
  let stream = make_stream "(1 2 3)" in
  let result = L.read_sexpr stream in
  match result with
  | O.Pair _ ->
    let rec check_list obj args =
      match obj, args with
      | O.Nil, [] -> ()
      | O.Pair (car, cdr), (expected :: rest) ->
        (match car with
         | O.Fixnum n -> check_int "list element" expected n
         | _ -> Alcotest.fail "Expected Fixnum in list");
        check_list cdr rest
      | _ -> Alcotest.fail "List structure mismatch"
    in
    check_list result [1; 2; 3]
  | _ -> Alcotest.fail "Expected Pair"

let test_read_simple_expr () =
  let stream = make_stream "(+ 1 2)" in
  let result = L.read_sexpr stream in
  match result with
  | O.Pair (car, cdr) ->
    (match car with
     | O.Symbol s -> check_string "list head +" "+" s
     | _ -> Alcotest.fail "Expected Symbol in car");
    (match cdr with
     | O.Pair (a, d) ->
       (match a with
        | O.Fixnum n -> check_int "first arg" 1 n
        | _ -> Alcotest.fail "Expected Fixnum");
       (match d with
        | O.Pair (b, O.Nil) ->
          (match b with
           | O.Fixnum n -> check_int "second arg" 2 n
           | _ -> Alcotest.fail "Expected Fixnum")
        | _ -> Alcotest.fail "Expected proper list")
     | _ -> Alcotest.fail "Expected pair in cdr")
  | _ -> Alcotest.fail "Expected Pair"

let test_read_nested_list () =
  let stream = make_stream "((1 2) (3 4))" in
  let result = L.read_sexpr stream in
  match result with
  | O.Pair (outer_car, _) ->
    (match outer_car with
     | O.Pair _ -> check_bool "nested list" true true
     | _ -> Alcotest.fail "Expected nested Pair")
  | _ -> Alcotest.fail "Expected outer Pair"

let test_read_symbol_with_special_chars () =
  let stream = make_stream "foo-bar? " in
  let result = L.read_sexpr stream in
  match result with
  | O.Symbol s -> check_string "symbol with special chars" "foo-bar?" s
  | _ -> Alcotest.fail "Expected Symbol"

let test_read_after_whitespace () =
  let stream = make_stream "   42 " in
  let result = L.read_sexpr stream in
  match result with
  | O.Fixnum n -> check_int "read after whitespace" 42 n
  | _ -> Alcotest.fail "Expected Fixnum"

let test_read_with_comment () =
  let stream = make_stream "; comment\n42 " in
  let result = L.read_sexpr stream in
  match result with
  | O.Fixnum n -> check_int "read after comment" 42 n
  | _ -> Alcotest.fail "Expected Fixnum"

let test_read_list_with_whitespace () =
  let stream = make_stream "  (  1   2   3  )  " in
  let result = L.read_sexpr stream in
  match result with
  | O.Pair (O.Fixnum 1, O.Pair (O.Fixnum 2, O.Pair (O.Fixnum 3, O.Nil))) ->
    check_bool "list with whitespace" true true
  | _ -> Alcotest.fail "Expected proper list"

(* Additional edge case tests *)

let test_read_string_with_escapes () =
  let stream = make_stream "\"hello\\nworld\"" in
  let result = L.read_sexpr stream in
  match result with
  | O.String s -> check_string "string with escape" "hello\nworld" s
  | _ -> Alcotest.fail "Expected String with escapes"

let test_read_string_with_quote_escape () =
  let stream = make_stream "\"say \\\"hello\\\"\"" in
  let result = L.read_sexpr stream in
  match result with
  | O.String s -> check_string "string with quote escape" "say \"hello\"" s
  | _ -> Alcotest.fail "Expected String with quote escape"

let test_read_float_leading_dot () =
  let stream = make_stream ".5 " in
  let result = L.read_sexpr stream in
  match result with
  | O.Float f -> check_bool "read float .5" true (Float.abs (f -. 0.5) < 0.001)
  | _ -> Alcotest.fail "Expected Float with leading dot"

let test_read_float_trailing_dot () =
  let stream = make_stream "5. " in
  let result = L.read_sexpr stream in
  match result with
  | O.Float f -> check_bool "read float 5." true (Float.abs (f -. 5.0) < 0.001)
  | _ -> Alcotest.fail "Expected Float with trailing dot"

let test_read_symbol_with_question () =
  let stream = make_stream "foo? " in
  let result = L.read_sexpr stream in
  match result with
  | O.Symbol s -> check_string "symbol with ?" "foo?" s
  | _ -> Alcotest.fail "Expected Symbol with ?"

let test_read_symbol_with_exclamation () =
  let stream = make_stream "foo! " in
  let result = L.read_sexpr stream in
  match result with
  | O.Symbol s -> check_string "symbol with !" "foo!" s
  | _ -> Alcotest.fail "Expected Symbol with !"

let test_read_symbol_with_underscore () =
  let stream = make_stream "foo_bar " in
  let result = L.read_sexpr stream in
  match result with
  | O.Symbol s -> check_string "symbol with _" "foo_bar" s
  | _ -> Alcotest.fail "Expected Symbol with _"

let test_read_quoted_list () =
  let stream = make_stream "'(1 2 3)" in
  let result = L.read_sexpr stream in
  match result with
  | O.Quote inner ->
    (match inner with
     | O.Pair (O.Fixnum 1, O.Pair (O.Fixnum 2, O.Pair (O.Fixnum 3, O.Nil))) ->
       check_bool "quoted list" true true
     | _ -> Alcotest.fail "Expected quoted list")
  | _ -> Alcotest.fail "Expected Quote"

let test_read_quasiquote_list () =
  let stream = make_stream "`(1 ,(+ 2 3))" in
  let result = L.read_sexpr stream in
  match result with
  | O.Quasiquote inner ->
    (match inner with
     | O.Pair _ -> check_bool "quasiquote list" true true
     | _ -> Alcotest.fail "Expected quasiquote list")
  | _ -> Alcotest.fail "Expected Quasiquote"

let test_read_nested_quote () =
  let stream = make_stream "''x" in
  let result = L.read_sexpr stream in
  match result with
  | O.Quote inner ->
    (match inner with
     | O.Quote _ -> check_bool "nested quote" true true
     | _ -> Alcotest.fail "Expected nested Quote")
  | _ -> Alcotest.fail "Expected Quote"

let test_read_list_with_nested_lists () =
  let stream = make_stream "((a b) (c d) (e f))" in
  let result = L.read_sexpr stream in
  match result with
  | O.Pair (O.Pair (O.Symbol "a", _), _) ->
    check_bool "list with nested lists" true true
  | _ -> Alcotest.fail "Expected list with nested lists"

(* Escape character tests *)

let test_read_string_with_newline () =
  let stream = make_stream "\"hello\\nworld\"" in
  let result = L.read_sexpr stream in
  match result with
  | O.String s ->
    Alcotest.(check string) "string with newline" "hello\nworld" s
  | _ -> Alcotest.fail "Expected String"

let test_read_string_with_tab () =
  let stream = make_stream "\"hello\\tworld\"" in
  let result = L.read_sexpr stream in
  match result with
  | O.String s ->
    Alcotest.(check string) "string with tab" "hello\tworld" s
  | _ -> Alcotest.fail "Expected String"

let test_read_string_with_escaped_quote () =
  let stream = make_stream "\"say \\\"hello\\\"\"" in
  let result = L.read_sexpr stream in
  match result with
  | O.String s ->
    Alcotest.(check string) "string with escaped quote" "say \"hello\"" s
  | _ -> Alcotest.fail "Expected String"

let test_read_string_with_backslash () =
  let stream = make_stream "\"path\\\\to\\\\file\"" in
  let result = L.read_sexpr stream in
  match result with
  | O.String s ->
    Alcotest.(check string) "string with backslash" "path\\to\\file" s
  | _ -> Alcotest.fail "Expected String"

let test_read_string_invalid_escape () =
  let stream = make_stream "\"hello\\z\"" in
  let result =
    try
      let _ = L.read_sexpr stream in
      Error "Expected Invalid_escape exception"
    with
    | Mlisp_error.Errors.Syntax_error_exn _ -> Ok ()
    | e -> Error (Printexc.to_string e)
  in
  match result with
  | Ok () -> ()
  | Error msg -> Alcotest.fail msg

let test_suite =
  ("lexer", [
     Alcotest.test_case "read fixnum" `Quick test_read_fixnum;
     Alcotest.test_case "read negative fixnum" `Quick test_read_negative_fixnum;
     Alcotest.test_case "read float" `Quick test_read_float;
     Alcotest.test_case "read negative float" `Quick test_read_negative_float;
     Alcotest.test_case "read string" `Quick test_read_string;
     Alcotest.test_case "read empty string" `Quick test_read_empty_string;
     Alcotest.test_case "read string unterminated" `Quick test_read_string_unterminated;
     Alcotest.test_case "read string with escapes" `Quick test_read_string_with_escapes;
     Alcotest.test_case "read string with quote escape" `Quick test_read_string_with_quote_escape;
     Alcotest.test_case "read float leading dot" `Quick test_read_float_leading_dot;
     Alcotest.test_case "read float trailing dot" `Quick test_read_float_trailing_dot;
     Alcotest.test_case "read symbol" `Quick test_read_symbol;
     Alcotest.test_case "read plus symbol" `Quick test_read_plus_symbol;
     Alcotest.test_case "read minus symbol" `Quick test_read_minus_symbol;
     Alcotest.test_case "read symbol with ?" `Quick test_read_symbol_with_question;
     Alcotest.test_case "read symbol with !" `Quick test_read_symbol_with_exclamation;
     Alcotest.test_case "read symbol with _" `Quick test_read_symbol_with_underscore;
     Alcotest.test_case "read boolean true" `Quick test_read_boolean_true;
     Alcotest.test_case "read boolean false" `Quick test_read_boolean_false;
     Alcotest.test_case "read quote" `Quick test_read_quote;
     Alcotest.test_case "read quasiquote" `Quick test_read_quasiquote;
     Alcotest.test_case "read unquote" `Quick test_read_unquote;
     Alcotest.test_case "read unquote-splicing" `Quick test_read_unquote_splicing;
     Alcotest.test_case "read quoted list" `Quick test_read_quoted_list;
     Alcotest.test_case "read quasiquote list" `Quick test_read_quasiquote_list;
     Alcotest.test_case "read nested quote" `Quick test_read_nested_quote;
     Alcotest.test_case "read nil symbol" `Quick test_read_nil_symbol;
     Alcotest.test_case "read empty list" `Quick test_read_empty_list;
     Alcotest.test_case "read simple list" `Quick test_read_simple_list;
     Alcotest.test_case "read simple expr" `Quick test_read_simple_expr;
     Alcotest.test_case "read nested list" `Quick test_read_nested_list;
     Alcotest.test_case "read list with nested lists" `Quick test_read_list_with_nested_lists;
     Alcotest.test_case "read symbol with special chars" `Quick test_read_symbol_with_special_chars;
     Alcotest.test_case "read after whitespace" `Quick test_read_after_whitespace;
     Alcotest.test_case "read with comment" `Quick test_read_with_comment;
      Alcotest.test_case "read list with whitespace" `Quick test_read_list_with_whitespace;
      Alcotest.test_case "string with newline" `Quick test_read_string_with_newline;
      Alcotest.test_case "string with tab" `Quick test_read_string_with_tab;
      Alcotest.test_case "string with escaped quote" `Quick test_read_string_with_escaped_quote;
      Alcotest.test_case "string with backslash" `Quick test_read_string_with_backslash;
      Alcotest.test_case "string invalid escape" `Quick test_read_string_invalid_escape;
    ])

let run () = Alcotest.run "test_lexer" [test_suite]

let () = run ()
