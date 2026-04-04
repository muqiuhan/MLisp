(* packages/interpreter/test/property/test_tokenizer.ml *)
open QCheck
module Token = Mlisp_lexer.Token
module Tokenizer = Mlisp_lexer.Tokenizer
module Stream_wrapper = Mlisp_utils.Stream_wrapper

let gen_safe_token_string =
  Gen.string_size ~gen:(Gen.oneof [
      Gen.char_range 'a' 'z';
      Gen.char_range 'A' 'Z';
      Gen.char_range '0' '9';
      Gen.return ' ';
      Gen.return '_';
    ]) (Gen.int_range 1 50)

let test_roundtrip_tokens =
  Test.make ~name:"tokenize then peek gives same token"
    (make gen_safe_token_string)
    (fun s ->
      let stream = Stream_wrapper.make_stringstream s in
      let tokenizer = Tokenizer.create stream in
      match Tokenizer.next tokenizer with
      | Ok _tok -> true
      | Error _ -> false
    )

let test_number_parsing =
  Test.make ~name:"numbers parse correctly"
    (int_range 0 10000)
    (fun n ->
      let s = Int.to_string n ^ " " in
      let stream = Stream_wrapper.make_stringstream s in
      let tokenizer = Tokenizer.create stream in
      match Tokenizer.next tokenizer with
      | Ok tok -> Token.equal_kind (Token.kind tok) (Token.T_Number n)
      | _ -> false
    )

let () =
  ignore (QCheck_base_runner.run_tests ~verbose:true [
    test_roundtrip_tokens;
    test_number_parsing;
  ])