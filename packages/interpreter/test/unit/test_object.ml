(** Alcotest tests for the Object module *)

module O = Mlisp_object.Object

let check_lobject_int = Alcotest.(check (option int))
let check_lobject_string = Alcotest.(check (option string))
let check_string = Alcotest.(check string)
let check_int = Alcotest.(check int)
let check_bool = Alcotest.(check bool)
let check_list_string = Alcotest.(check (list string))
let check_list_int = Alcotest.(check (list int))

let test_lobject_equality () =
  let fixnum1 = O.Fixnum 42 in
  let fixnum2 = O.Fixnum 42 in
  let fixnum3 = O.Fixnum 100 in
  check_bool "Fixnum 42 = Fixnum 42" true (fixnum1 = fixnum2);
  check_bool "Fixnum 42 <> Fixnum 100" true (fixnum1 <> fixnum3)

let test_lobject_types () =
  check_string "Fixnum type" "int" (O.object_type (O.Fixnum 42));
  check_string "Float type" "float" (O.object_type (O.Float 3.14));
  check_string "Boolean type" "boolean" (O.object_type (O.Boolean true));
  check_string "Boolean false type" "boolean" (O.object_type (O.Boolean false));
  check_string "Symbol type" "symbol" (O.object_type (O.Symbol "foo"));
  check_string "String type" "string" (O.object_type (O.String "hello"));
  check_string "Nil type" "nil" (O.object_type O.Nil);
  check_string "Pair type" "pair" (O.object_type (O.Pair (O.Fixnum 1, O.Fixnum 2)));
  check_string "Primitive type" "primitive" (O.object_type (O.Primitive ("+", fun _ -> O.Nil)));
  check_string "Quote type" "quote" (O.object_type (O.Quote (O.Symbol "x")));
  check_string "Quasiquote type" "quasiquote" (O.object_type (O.Quasiquote (O.Symbol "x")));
  check_string "Unquote type" "unquote" (O.object_type (O.Unquote (O.Symbol "x")));
  check_string "UnquoteSplicing type" "unquote-splicing" (O.object_type (O.UnquoteSplicing (O.Symbol "x")));
  check_string "RestParam type" "rest-param" (O.object_type (O.RestParam "args"));
  check_string "Closure type" "closure" (O.object_type (O.Closure ("f", [], O.Literal O.Nil, O.Legacy (O.create_env ()))));
  check_string "Macro type" "macro" (O.object_type (O.Macro ("m", [], O.Literal O.Nil, O.create_env ())));
  check_string "Record type" "record" (O.object_type (O.Record ("r", [])));
  check_string "Module type" "module" (O.object_type (O.Module { name = "test"; env = O.create_env (); exports = [] }))

let test_is_list () =
  check_bool "Nil is a list" true (O.is_list O.Nil);
  check_bool "Proper list is a list" true (O.is_list (O.Pair (O.Fixnum 1, O.Pair (O.Fixnum 2, O.Pair (O.Fixnum 3, O.Nil)))));
  check_bool "Dotted pair is not a list" false (O.is_list (O.Pair (O.Fixnum 1, O.Fixnum 2)));
  check_bool "Fixnum is not a list" false (O.is_list (O.Fixnum 42));
  check_bool "Symbol is not a list" false (O.is_list (O.Symbol "foo"))

let pair_to_string_list l = Core.List.map l ~f:O.string_object

let test_pair_to_list () =
  check_list_string "pair_to_list nil" [] (pair_to_string_list (O.pair_to_list O.Nil));
  check_list_string "pair_to_list single" ["1"] (pair_to_string_list (O.pair_to_list (O.Pair (O.Fixnum 1, O.Nil))));
  check_list_string "pair_to_list multiple" ["1"; "2"; "3"] (pair_to_string_list (O.pair_to_list (O.Pair (O.Fixnum 1, O.Pair (O.Fixnum 2, O.Pair (O.Fixnum 3, O.Nil))))))

let test_list_to_pair () =
  check_string "list_to_pair empty" "nil" (O.string_object (O.list_to_pair []));
  check_string "list_to_pair single" "(1)\n" (O.string_object (O.list_to_pair [O.Fixnum 1]));
  check_string "list_to_pair multiple" "(1 2 3)\n" (O.string_object (O.list_to_pair [O.Fixnum 1; O.Fixnum 2; O.Fixnum 3]))

let test_pair_list_roundtrip () =
  let original = [O.Fixnum 1; O.Fixnum 2; O.Symbol "foo"; O.String "bar"] in
  let as_pair = O.list_to_pair original in
  let back_to_list = O.pair_to_list as_pair in
  check_list_string "roundtrip conversion" ["1"; "2"; "foo"; "\"bar\""] (pair_to_string_list back_to_list)

let test_append_lists () =
  let nil = O.Nil in
  let list1 = O.Pair (O.Fixnum 1, O.Pair (O.Fixnum 2, O.Nil)) in
  let list2 = O.Pair (O.Fixnum 3, O.Pair (O.Fixnum 4, O.Nil)) in
  let result = O.append_lists list1 list2 in
  check_list_string "append_lists basic" ["1"; "2"; "3"; "4"] (pair_to_string_list (O.pair_to_list result));
  check_string "append_lists first nil" "(3 4)\n" (O.string_object (O.append_lists nil list2));
  check_string "append_lists second nil" "(1 2)\n" (O.string_object (O.append_lists list1 nil))

let test_parse_dotted_symbol () =
  Alcotest.(check (option (pair string string))) "simple dotted symbol" (Some ("math", "add")) (O.parse_dotted_symbol "math.add");
  Alcotest.(check (option (pair string string))) "deeper nesting" (Some ("a", "b")) (O.parse_dotted_symbol "a.b");
  Alcotest.(check (option (pair string string))) "no dot" None (O.parse_dotted_symbol "foo");
  Alcotest.(check (option (pair string string))) "dot at start" None (O.parse_dotted_symbol ".foo");
  Alcotest.(check (option (pair string string))) "dot at end" None (O.parse_dotted_symbol "foo.")

let test_create_env () =
  let env = O.create_env () in
  check_int "env level is 0" 0 env.O.level;
  check_bool "env has no parent" true (Option.is_none env.O.parent);
  check_int "bindings size is 0" 0 (Base.Hashtbl.length env.O.bindings)

let test_extend_env () =
  let parent = O.create_env () in
  let child = O.extend_env parent in
  check_int "child level is 1" 1 child.O.level;
  check_bool "child has parent" true (Option.is_some child.O.parent)

let test_bind_and_lookup () =
  let env = O.create_env () in
  let (_ : O.lobject O.env) = O.bind ("x", O.Fixnum 42, env) in
  let (_ : O.lobject O.env) = O.bind ("y", O.String "hello", env) in
  let x_val = O.lookup ("x", env) in
  let y_val = O.lookup ("y", env) in
  check_lobject_int "lookup x" (Some 42) (match x_val with O.Fixnum n -> Some n | _ -> None);
  check_lobject_string "lookup y" (Some "hello") (match y_val with O.String s -> Some s | _ -> None)

let test_bind_local () =
  let env = O.create_env () in
  let local_ref = O.make_local () in
  let (_ : O.lobject O.env) = O.bind_local ("x", local_ref, env) in
  check_bool "local bound" true (Option.is_some (Base.Hashtbl.find env.O.bindings "x"))

let test_bind_list () =
  let env = O.create_env () in
  let (_ : O.lobject O.env) = O.bind_list ["a"; "b"; "c"] [O.Fixnum 1; O.Fixnum 2; O.Fixnum 3] env in
  let val_env = O.env_to_val env in
  let items = O.pair_to_list val_env in
  let values = Core.List.map items ~f:(function O.Pair (O.Symbol _, O.Fixnum n) -> n | _ -> 0) in
  check_list_int "bind_list results" [1; 2; 3] (Core.List.sort values ~compare:Int.compare)

let test_env_to_val () =
  let env = O.create_env () in
  let (_ : O.lobject O.env) = O.bind ("x", O.Fixnum 1, env) in
  let (_ : O.lobject O.env) = O.bind ("y", O.Fixnum 2, env) in
  let val_env = O.env_to_val env in
  check_bool "env_to_val is a list" true (O.is_list val_env)

let test_closure_env_creation () =
  let env = O.create_env () in
  let (_ : O.lobject O.env) = O.bind ("x", O.Fixnum 10, env) in
  let (_ : O.lobject O.env) = O.bind ("y", O.Fixnum 20, env) in
  let closure_env = O.create_closure_env ["x"; "y"] env in
  check_int "captured vars count" 2 (Core.List.length closure_env.O.captured_vars);
  check_bool "has parent env" true (Option.is_some closure_env.O.parent_env)

let test_lookup_in_closure () =
  let env = O.create_env () in
  let (_ : O.lobject O.env) = O.bind ("x", O.Fixnum 42, env) in
  let (_ : O.lobject O.env) = O.bind ("y", O.Fixnum 100, env) in
  let closure_env = O.create_closure_env ["x"] env in
  match O.lookup_in_closure "x" closure_env with
  | O.Fixnum n -> check_int "lookup x in closure" 42 n
  | _ -> Alcotest.fail "Expected Fixnum"

let test_module_record () =
  let env = O.create_env () in
  let (_ : O.lobject O.env) = O.bind ("a", O.Fixnum 1, env) in
  let m = O.Module { name = "testmod"; env; exports = ["a"] } in
  check_string "module type" "module" (O.object_type m);
  match m with
  | O.Module { name; exports; _ } ->
    check_string "module name" "testmod" name;
    Alcotest.(check (list string)) "module exports" ["a"] exports
  | _ -> Alcotest.fail "Expected Module"

let test_record () =
  let fields = [("x", O.Fixnum 1); ("y", O.Fixnum 2)] in
  let record = O.Record ("point", fields) in
  check_string "record type" "record" (O.object_type record);
  match record with
  | O.Record (name, fields) ->
    check_string "record name" "point" name;
    check_int "field count" 2 (Core.List.length fields)
  | _ -> Alcotest.fail "Expected Record"

let test_string_object () =
  check_string "string_object Fixnum" "42" (O.string_object (O.Fixnum 42));
  check_string "string_object Float" "3.14" (O.string_object (O.Float 3.14));
  check_string "string_object Boolean true" "#t" (O.string_object (O.Boolean true));
  check_string "string_object Boolean false" "#f" (O.string_object (O.Boolean false));
  check_string "string_object Symbol" "foo" (O.string_object (O.Symbol "foo"));
  check_string "string_object String" "\"hello\"" (O.string_object (O.String "hello"));
  check_string "string_object Nil" "nil" (O.string_object O.Nil);
  check_string "string_object Quote" "'foo" (O.string_object (O.Quote (O.Symbol "foo")))

let test_suite =
  ("object", [
     Alcotest.test_case "lobject equality" `Quick test_lobject_equality;
     Alcotest.test_case "lobject types" `Quick test_lobject_types;
     Alcotest.test_case "is_list" `Quick test_is_list;
     Alcotest.test_case "pair_to_list" `Quick test_pair_to_list;
     Alcotest.test_case "list_to_pair" `Quick test_list_to_pair;
     Alcotest.test_case "pair_list_roundtrip" `Quick test_pair_list_roundtrip;
     Alcotest.test_case "append_lists" `Quick test_append_lists;
     Alcotest.test_case "parse_dotted_symbol" `Quick test_parse_dotted_symbol;
     Alcotest.test_case "create_env" `Quick test_create_env;
     Alcotest.test_case "extend_env" `Quick test_extend_env;
     Alcotest.test_case "bind_and_lookup" `Quick test_bind_and_lookup;
     Alcotest.test_case "bind_local" `Quick test_bind_local;
     Alcotest.test_case "bind_list" `Quick test_bind_list;
     Alcotest.test_case "env_to_val" `Quick test_env_to_val;
     Alcotest.test_case "closure_env_creation" `Quick test_closure_env_creation;
     Alcotest.test_case "lookup_in_closure" `Quick test_lookup_in_closure;
     Alcotest.test_case "module_record" `Quick test_module_record;
     Alcotest.test_case "record" `Quick test_record;
     Alcotest.test_case "string_object" `Quick test_string_object;
   ])

let run () = Alcotest.run "test_object" [test_suite]

let () = run ()
