(** Alcotest tests for the Sexpr module *)

module S = Mlisp_object.Sexpr
module T = Mlisp_object.Types

let check_int = Alcotest.(check int)
let check_bool = Alcotest.(check bool)
let check_string = Alcotest.(check string)

let test_pair_to_list () =
  let pair = T.Pair (T.Fixnum 1, T.Pair (T.Fixnum 2, T.Pair (T.Fixnum 3, T.Nil))) in
  let list = S.pair_to_list pair in
  check_int "pair_to_list length" 3 (List.length list)

let test_list_to_pair () =
  let list = [T.Fixnum 1; T.Fixnum 2; T.Fixnum 3] in
  let pair = S.list_to_pair list in
  check_bool "list_to_pair is_list" true (S.is_list pair)

let test_append_lists () =
  let l1 = T.Pair (T.Fixnum 1, T.Pair (T.Fixnum 2, T.Nil)) in
  let l2 = T.Pair (T.Fixnum 3, T.Pair (T.Fixnum 4, T.Nil)) in
  let result = S.append_lists l1 l2 in
  check_int "append_lists length" 4 (List.length (S.pair_to_list result))

let test_is_list () =
  check_bool "Nil is list" true (S.is_list T.Nil);
  check_bool "Proper list is list" true (S.is_list (T.Pair (T.Fixnum 1, T.Pair (T.Fixnum 2, T.Nil))));
  check_bool "Dotted pair is not list" false (S.is_list (T.Pair (T.Fixnum 1, T.Fixnum 2)));
  check_bool "Atom is not list" false (S.is_list (T.Fixnum 42))

let test_string_object () =
  check_string "string_object Fixnum" "42" (S.string_object (T.Fixnum 42));
  check_string "string_object Symbol" "foo" (S.string_object (T.Symbol "foo"));
  check_string "string_object Nil" "nil" (S.string_object T.Nil);
  check_string "string_object list" "(1 2)\n" (S.string_object (T.Pair (T.Fixnum 1, T.Pair (T.Fixnum 2, T.Nil))))

let test_suite =
  ("sexpr", [
     Alcotest.test_case "pair_to_list" `Quick test_pair_to_list;
     Alcotest.test_case "list_to_pair" `Quick test_list_to_pair;
     Alcotest.test_case "append_lists" `Quick test_append_lists;
     Alcotest.test_case "is_list" `Quick test_is_list;
     Alcotest.test_case "string_object" `Quick test_string_object;
   ])

let run () = Alcotest.run "test_sexpr" [test_suite]

let () = run ()
