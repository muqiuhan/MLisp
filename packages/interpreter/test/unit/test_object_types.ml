(* packages/interpreter/test/unit/test_object_types.ml *)

open Core

(* Helper to create a minimal environment *)
let make_env () : Mlisp_object.Types.lobject Mlisp_object.Types.env =
  let open Mlisp_object.Types in
  { bindings = Hashtbl.create (module String)
  ; parent = None
  ; level = 0
  }

let test_lobject_constructors () =
  let fixnum : Mlisp_object.Types.lobject = Mlisp_object.Types.Fixnum 42 in
  Alcotest.(check string) "Fixnum type" "int" (Mlisp_object.Types.object_type fixnum)

let test_expr_constructors () =
  let expr : Mlisp_object.Types.expr = Mlisp_object.Types.Literal (Mlisp_object.Types.Fixnum 42) in
  match expr with
  | Mlisp_object.Types.Literal _ -> Alcotest.(check unit) "expr works" () ()
  | _ -> Alcotest.fail "expected Literal"

(* Test object_type function for all lobject variants *)
let test_object_type_float () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Float 3.14 in
  Alcotest.(check string) "Float type" "float" (Mlisp_object.Types.object_type obj)

let test_object_type_boolean () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Boolean true in
  Alcotest.(check string) "Boolean type" "boolean" (Mlisp_object.Types.object_type obj)

let test_object_type_string () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.String "hello" in
  Alcotest.(check string) "String type" "string" (Mlisp_object.Types.object_type obj)

let test_object_type_symbol () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Symbol "foo" in
  Alcotest.(check string) "Symbol type" "symbol" (Mlisp_object.Types.object_type obj)

let test_object_type_nil () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Nil in
  Alcotest.(check string) "Nil type" "nil" (Mlisp_object.Types.object_type obj)

let test_object_type_pair () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Pair (Mlisp_object.Types.Nil, Mlisp_object.Types.Nil) in
  Alcotest.(check string) "Pair type" "pair" (Mlisp_object.Types.object_type obj)

let test_object_type_primitive () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Primitive ("+", fun _ -> Mlisp_object.Types.Nil) in
  Alcotest.(check string) "Primitive type" "primitive" (Mlisp_object.Types.object_type obj)

let test_object_type_quote () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Quote (Mlisp_object.Types.Symbol "x") in
  Alcotest.(check string) "Quote type" "quote" (Mlisp_object.Types.object_type obj)

let test_object_type_quasiquote () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Quasiquote (Mlisp_object.Types.Symbol "x") in
  Alcotest.(check string) "Quasiquote type" "quasiquote" (Mlisp_object.Types.object_type obj)

let test_object_type_unquote () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Unquote (Mlisp_object.Types.Symbol "x") in
  Alcotest.(check string) "Unquote type" "unquote" (Mlisp_object.Types.object_type obj)

let test_object_type_unquote_splicing () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.UnquoteSplicing (Mlisp_object.Types.Symbol "x") in
  Alcotest.(check string) "UnquoteSplicing type" "unquote-splicing" (Mlisp_object.Types.object_type obj)

let test_object_type_rest_param () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.RestParam "args" in
  Alcotest.(check string) "RestParam type" "rest-param" (Mlisp_object.Types.object_type obj)

let test_object_type_closure () =
  let env = make_env () in
  let closure_data = Mlisp_object.Types.Legacy env in
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Closure ("f", [], Mlisp_object.Types.Literal (Mlisp_object.Types.Nil), closure_data) in
  Alcotest.(check string) "Closure type" "closure" (Mlisp_object.Types.object_type obj)

let test_object_type_macro () =
  let env = make_env () in
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Macro ("m", [], Mlisp_object.Types.Literal (Mlisp_object.Types.Nil), env) in
  Alcotest.(check string) "Macro type" "macro" (Mlisp_object.Types.object_type obj)

let test_object_type_record () =
  let obj : Mlisp_object.Types.lobject = Mlisp_object.Types.Record ("point", [("x", Mlisp_object.Types.Fixnum 1)]) in
  Alcotest.(check string) "Record type" "record" (Mlisp_object.Types.object_type obj)

let test_object_type_module () =
  let env = make_env () in
  let module_obj = Mlisp_object.Types.Module
    { name = "test"
    ; env
    ; exports = []
    } in
  Alcotest.(check string) "Module type" "module" (Mlisp_object.Types.object_type module_obj)

let test_suite = [
  ("lobject_constructors", [
     Alcotest.test_case "Fixnum type check" `Quick test_lobject_constructors;
     Alcotest.test_case "expr Literal constructor" `Quick test_expr_constructors;
  ]);
  ("object_type", [
     Alcotest.test_case "Float type" `Quick test_object_type_float;
     Alcotest.test_case "Boolean type" `Quick test_object_type_boolean;
     Alcotest.test_case "String type" `Quick test_object_type_string;
     Alcotest.test_case "Symbol type" `Quick test_object_type_symbol;
     Alcotest.test_case "Nil type" `Quick test_object_type_nil;
     Alcotest.test_case "Pair type" `Quick test_object_type_pair;
     Alcotest.test_case "Primitive type" `Quick test_object_type_primitive;
     Alcotest.test_case "Quote type" `Quick test_object_type_quote;
     Alcotest.test_case "Quasiquote type" `Quick test_object_type_quasiquote;
     Alcotest.test_case "Unquote type" `Quick test_object_type_unquote;
     Alcotest.test_case "UnquoteSplicing type" `Quick test_object_type_unquote_splicing;
     Alcotest.test_case "RestParam type" `Quick test_object_type_rest_param;
     Alcotest.test_case "Closure type" `Quick test_object_type_closure;
     Alcotest.test_case "Macro type" `Quick test_object_type_macro;
     Alcotest.test_case "Record type" `Quick test_object_type_record;
     Alcotest.test_case "Module type" `Quick test_object_type_module;
  ]);
]

let run () =
  Alcotest.run "test_object_types" test_suite
