# OCaml Library Binding System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建一个通用的 OCaml 库绑定系统，使 MLisp 能够通过模块 Record 对象访问 OCaml 库（Yojson、Calendar、Cohttp 等），无需修改词法分析和 AST。

**架构:**
1. 类型转换层 (converter.ml) - MLisp Object 与 OCaml 值的双向转换
2. 模块构建器 (module_builder.ml) - 声明式创建 MLisp Record 模块
3. 各库绑定模块 - 每个库一个文件，声明式绑定 OCaml 函数
4. 自动注册系统 - 收集所有模块绑定，注册到 Basis 环境

**Tech Stack:** OCaml 5.0+, Dune 3.3+, Core, yojson, calendar, cohttp-lwt-unix, lwt

---

## 依赖添加

### Task 1: 添加外部库依赖

**Files:**
- Modify: `dune-project`
- Modify: `mlisp.opam`

**Step 1: 修改 dune-project 添加依赖**

Read: `dune-project`

Edit: 在 `(depends ...)` 行添加新的依赖：

```lisp
(package
 (name mlisp)
 (version 0.0.44)
 (synopsis "A Lisp implementation in OCaml")
 (description "A Lisp implementation in OCaml")
 (depends ocaml dune core ocolor camlp-streams ocamline core_unix ppx_string yojson calendar cohttp-lwt-unix lwt))
```

**Step 2: 运行 opam 安装依赖**

Run: `opam install . --deps-only`

Expected: 安装 yojson, calendar, cohttp-lwt-unix, lwt

**Step 3: 提交**

```bash
git add dune-project mlisp.opam
git commit -m "feat: add yojson, calendar, cohttp dependencies"
```

---

## Phase 1: 类型转换层

### Task 2: 创建类型转换器模块

**Files:**
- Create: `lib/primitives/converter.ml`

**Step 1: 创建 converter.ml 基础结构**

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core

(** Type Converter - Bidirectional conversion between MLisp and OCaml values *)

(** OCaml generic value for flexible type handling *)
type ocaml_value =
  | OVUnit
  | OVBool of bool
  | OVInt of int
  | OVFloat of float
  | OVString of string
  | OVList of ocaml_value list
  | OVOption of ocaml_value option
  | OVPair of ocaml_value * ocaml_value
  | OVRecord of (string * ocaml_value) list
  | OVJson of Yojson.Basic.t
  | OVDate of CalendarLib.Date.t

(** MLisp Object to OCaml value *)
let rec lobject_to_ocaml = function
  | Object.Nil -> OVUnit
  | Object.Boolean b -> OVBool b
  | Object.Fixnum i -> OVInt i
  | Object.Float f -> OVFloat f
  | Object.String s -> OVString s
  | Object.Pair (car, cdr) ->
      let car' = lobject_to_ocaml car in
      let cdr' = lobject_to_ocaml cdr in
      OVPair (car', cdr')
  | Object.Record (_, fields) ->
      let fields' = List.map fields ~f:(fun (k, v) -> (k, lobject_to_ocaml v)) in
      OVRecord fields'
  | _ -> raise (Errors.Runtime_error_exn (Errors.Type_error "Cannot convert to OCaml value"))

(** OCaml value to MLisp Object *)
let rec ocaml_to_lobject = function
  | OVUnit -> Object.Nil
  | OVBool b -> Object.Boolean b
  | OVInt i -> Object.Fixnum i
  | OVFloat f -> Object.Float f
  | OVString s -> Object.String s
  | OVList lst ->
      List.fold_right lst ~init:Object.Nil ~f:(fun v acc ->
        Object.Pair (ocaml_to_lobject v, acc))
  | OVOption None -> Object.Nil
  | OVOption (Some v) -> ocaml_to_lobject v
  | OVPair (v1, v2) -> Object.Pair (ocaml_to_lobject v1, ocaml_to_lobject v2)
  | OVRecord fields ->
      let fields' = List.map fields ~f:(fun (k, v) -> (k, ocaml_to_lobject v)) in
      Object.Record ("OCamlRecord", fields')
  | OVJson json -> json_to_lobject json
  | OVDate date -> Object.Date date

(** Extract string argument with error handling *)
let get_string args index =
  try
    match List.nth args index with
    | Object.String s -> s
    | _ -> raise (Errors.Runtime_error_exn (Errors.Type_error "Expected string argument"))
  with
  | _ -> raise (Errors.Runtime_error_exn (Errors.Not_found "Argument index out of bounds"))

(** Extract int argument with error handling *)
let get_int args index =
  try
    match List.nth args index with
    | Object.Fixnum i -> i
    | _ -> raise (Errors.Runtime_error_exn (Errors.Type_error "Expected int argument"))
  with
  | _ -> raise (Errors.Runtime_error_exn (Errors.Not_found "Argument index out of bounds"))

(** Extract float argument with error handling *)
let get_float args index =
  try
    match List.nth args index with
    | Float f -> f
    | Fixnum i -> float_of_int i
    | _ -> raise (Errors.Runtime_error_exn (Errors.Type_error "Expected float argument"))
  with
  | _ -> raise (Errors.Runtime_error_exn (Errors.Not_found "Argument index out of bounds"))

(** Extract list argument with error handling *)
let get_list args index =
  try
    match List.nth args index with
    | Object.Pair _ | Object.Nil as lst -> lst
    | _ -> raise (Errors.Runtime_error_exn (Errors.Type_error "Expected list argument"))
  with
  | _ -> raise (Errors.Runtime_error_exn (Errors.Not_found "Argument index out of bounds"))

(** Argument count validation *)
let expect_arity args expected =
  let rec count = function
    | Object.Nil -> 0
    | Object.Pair (_, t) -> 1 + count t
    | _ -> 1
  in
  let actual = count args in
  if actual <> expected then
    raise (Errors.Runtime_error_exn (Errors.Type_error
      [%string "Arity error: expected %{Int.to_string expected}, got %{Int.to_string actual}"]))

(** JSON conversion functions *)
and json_to_lobject = function
  | `Null -> Object.Nil
  | `Bool b -> Object.Boolean b
  | `Int i -> Object.Fixnum i
  | `Float f -> Object.Float f
  | `String s -> Object.String s
  | `List arr ->
      Array.fold_right arr ~init:Object.Nil ~f:(fun v acc ->
        Object.Pair (json_to_lobject v, acc))
  | `Assoc fields ->
      let fields_list = List.map fields ~f:(fun (k, v) ->
        (k, json_to_lobject v)) in
      Object.Record ("JsonObject", fields_list)
  | `Bool _ | `Intlit _ | `Stringlit _ | `Tuple _ as json ->
      (* Handle legacy/literal forms *)
      json_to_lobject (Yojson.BasicUtil.merge json)

(** lobject to JSON *)
let lobject_to_json = function
  | Object.Nil -> `Null
  | Object.Boolean b -> `Bool b
  | Object.Fixnum i -> `Int i
  | Object.Float f -> `Float f
  | Object.String s -> `String s
  | Object.Pair (car, cdr) ->
      (* Convert Lisp list to JSON array *)
      let rec pair_to_list acc = function
        | Object.Nil -> List.rev acc
        | Object.Pair (h, t) -> pair_to_list (h :: acc) t
        | x -> List.rev (x :: acc)
      in
      `List (pair_to_list [] (Object.Pair (car, cdr)))
  | Object.Record (_, fields) ->
      `Assoc (List.map fields ~f:(fun (k, v) -> (k, lobject_to_json v)))
  | _ ->
      raise (Errors.Runtime_error_exn (Errors.Type_error "Cannot convert to JSON"))

(** JSON path navigation *)
let json_get_path obj path_str =
  let json = lobject_to_json obj in
  let segments = String.split ~on:'.' path_str in
  let rec navigate json segs =
    match segs, json with
    | [], _ -> json
    | seg :: rest, `Assoc fields ->
        (match List.find fields ~f:(fun (k, _) -> String.equal k seg) with
        | Some (_, value) -> navigate value rest
        | None -> `Null)
    | seg :: rest, `List arr ->
        (try
           let idx = int_of_string seg in
           if idx >= 0 && idx < Array.length arr then
             navigate arr.(idx) rest
           else
             `Null
         with
         | _ -> `Null)
    | _ -> `Null
  in
  json_to_lobject (navigate json segments)
```

**Step 2: 更新 dune 文件包含 converter**

Create: `lib/primitives/dune`

```lisp
(library
 (name mlisp_primitives)
 (public_name mlisp.primitives)
 (libraries core core_unix ocolor camlp-streams ppx_string yojson calendar cohttp-lwt-unix lwt)
 (modules basis std num string module converter module_builder json_binding date_binding string_ext_binding http_binding set_binding))
```

**Step 3: 提交**

```bash
git add lib/primitives/converter.ml lib/primitives/dune
git commit -m "feat: add type converter for OCaml library bindings"
```

---

## Phase 2: 模块构建器

### Task 3: 创建模块构建器

**Files:**
- Create: `lib/primitives/module_builder.ml`

**Step 1: 创建 module_builder.ml**

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core

(** Module Builder - Declarative creation of MLisp Record modules *)

(** Module signature - all binding modules must implement this *)
module type Module_sig = sig
  val name : string
  val bindings : (string * (lobject list -> lobject)) list
end

(** Create a module Record from bindings *)
let make_module module_name bindings =
  List.map bindings ~f:(fun (fn_name, fn) ->
    (fn_name, Object.Primitive (fn_name, fn)))
  |> fun fields ->
  Object.Record (module_name, fields)

(** Register a single module to environment *)
let register_module (type sig) (module : (module sig)) env =
  let module_obj = make_module module.name module.bindings in
  Object.bind (module.name, module_obj, env)

(** Register multiple modules at once *)
let register_all_modules modules env =
  List.fold_left modules ~init:env ~f:(fun env (module : Module_sig) ->
    register_module module env)

(** Helper: Create a primitive wrapper with type checking *)
let primitive_wrapper name arity handler =
  fun args ->
    let actual_arity =
      let rec count = function
        | Object.Nil -> 0
        | Object.Pair (_, t) -> 1 + count t
        | _ -> 1
      in
      count args
    in
    if actual_arity <> arity then
      raise (Errors.Runtime_error_exn (Errors.Type_error
        [%string "Arity error for %{name}: expected %{Int.to_string arity}, got %{Int.to_string actual_arity}"]));
    handler args

(** Helper: Create a variadic primitive (min to max args) *)
let variadic_primitive name min_args max_args handler =
  fun args ->
    let rec count = function
      | Object.Nil -> 0
      | Object.Pair (_, t) -> 1 + count t
      | _ -> 1
    in
    let actual = count args in
    if actual < min_args || actual > max_args then
      raise (Errors.Runtime_error_exn (Errors.Type_error
        [%string "Arity error for %{name}: expected %{Int.to_string min_args}-%{Int.to_string max_args}, got %{Int.to_string actual}"]));
    handler args
```

**Step 2: 提交**

```bash
git add lib/primitives/module_builder.ml
git commit -m "feat: add module builder for declarative OCaml bindings"
```

---

## Phase 3: JSON 模块绑定

### Task 4: 创建 JSON 模块绑定

**Files:**
- Create: `lib/primitives/json_binding.ml`

**Step 1: 创建 json_binding.ml**

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core
open Module_builder
open Converter

(** JSON Module Binding - wraps Yojson.Basic *)

module Json = struct
  let name = "Json"

  let bindings = [
    "parse", (fun args ->
      match args with
      | [Object.String json_str] ->
          begin try
            let json = Yojson.Basic.from_string json_str in
            Converter.json_to_lobject json
          with
          | Yojson.Json_error msg ->
            raise (Errors.Runtime_error_exn
              (Errors.Parse_error ([%string "JSON parse error: %{msg}"])))
          end
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Json.parse string)")));

    "stringify", (fun args ->
      match args with
      | [obj] ->
          let json = Converter.lobject_to_json obj in
          Object.String (Yojson.Basic.to_string json)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Json.stringify object)")));

    "stringify-pretty", (fun args ->
      match args with
      | [obj] ->
          let json = Converter.lobject_to_json obj in
          Object.String (Yojson.Basic.pretty_to_string json)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Json.stringify-pretty object)")));

    "get", (fun args ->
      match args with
      | [obj; Object.String path] ->
          Converter.json_get_path obj path
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Json.get object path-string)")));

    "null?", (fun args ->
      match args with
      | [Object.Nil] -> Object.Boolean true
      | _ -> Object.Boolean false);

    "bool?", (fun args ->
      match args with
      | [Object.Boolean _] -> Object.Boolean true
      | _ -> Object.Boolean false);

    "number?", (fun args ->
      match args with
      | [Object.Fixnum _ | Object.Float _] -> Object.Boolean true
      | _ -> Object.Boolean false);

    "string?", (fun args ->
      match args with
      | [Object.String _] -> Object.Boolean true
      | _ -> Object.Boolean false);

    "list?", (fun args ->
      match args with
      | [Object.Pair _] -> Object.Boolean true
      | _ -> Object.Boolean false);

    "object?", (fun args ->
      match args with
      | [Object.Record _] -> Object.Boolean true
      | _ -> Object.Boolean false);
  ]
end

include (Json : Module_sig)
```

**Step 2: 注册 Json 模块到 Basis**

Modify: `lib/primitives/basis.ml`

在文件末尾添加：

```ocaml
open Mlisp_object
open Mlisp_error
open Module_builder
open Json_binding

(** Register all library modules to Basis *)
let register_library_modules basis_env =
  register_all_modules [
    (module Json : Module_sig);
    (* More modules will be added here *)
  ] basis_env

let basis =
  let base_basis = [
    "list", list;
    (* ... existing bindings ... *)
  ] in
  List.map base_basis ~f:(fun (name, fn) ->
    (name, Object.Primitive (name, fn)))
  |> fun primitives ->
  List.fold_left primitives ~init:Object.global_env ~f:(fun env (name, prim) ->
    Object.bind (name, prim, env))
  |> register_library_modules
```

**Step 3: 创建测试文件**

Create: `test/30_json_module.mlisp`

```lisp
;; Test 1: Json.parse - Parse simple JSON object
(define obj (Json.parse "{\"name\": \"John\", \"age\": 30}"))
(print obj)

;; Test 2: Json.stringify - Convert back to JSON string
(define json-str (Json.stringify obj))
(print json-str)

;; Test 3: Json.stringify-pretty - Pretty print
(define pretty (Json.stringify-pretty obj))
(print pretty)

;; Test 4: Json.get - Path access
(define patient (Json.parse "{\"id\": \"123\", \"name\": \"Bob\", \"conditions\": [{\"code\": \"E11\"}]}"))
(print (Json.get patient "name"))
(print (Json.get patient "conditions.0.code"))

;; Test 5: Type predicates
(print (Json.object? obj))
(print (Json.string? (Json.parse "\"hello\"")))
(print (Json.number? (Json.parse "42")))
(print (Json.list? (Json.parse "[1,2,3]")))
(print (Json.null? (Json.parse "null")))

;; Test 6: Parse array
(define arr (Json.parse "[1, 2, 3, 4, 5]"))
(print arr)

(print "All Json module tests passed!")
```

**Step 4: 运行测试**

Run: `dune exec mlisp -- test/30_json_module.mlisp`

Expected: 所有测试通过，输出解析结果

**Step 5: 提交**

```bash
git add lib/primitives/json_binding.ml lib/primitives/basis.ml test/30_json_module.mlisp
git commit -m "feat: add Json module binding"
```

---

## Phase 4: Date 模块绑定

### Task 5: 添加 Date 类型到 Object

**Files:**
- Modify: `lib/object/object.ml`

**Step 1: 添加 Date 构造子**

Read: `lib/object/object.ml` (lines 1-50)

Edit: 在 `type lobject =` 中添加 Date 类型：

```ocaml
type lobject =
  | Fixnum of int
  | Float of float
  | Boolean of bool
  | Symbol of string
  | String of string
  | Nil
  | Pair of lobject * lobject
  | Record of name * (name * lobject) list
  | Primitive of string * (lobject list -> lobject)
  | Quote of value
  | Quasiquote of value
  | Unquote of value
  | UnquoteSplicing of value
  | Closure of name * name list * expr * closure_data
  | Macro of name * name list * expr * lobject env
  | Module of
      { name : string
      ; env : lobject env
      ; exports : string list
      }
  | Date of CalendarLib.Date.t  (** Add this line *)
```

**Step 2: 更新 object_type 函数**

Edit: 在 `let object_type = function` 中添加：

```ocaml
let object_type = function
  | ...
  | Date _ -> "date"
  | ...
```

**Step 3: 更新打印函数**

Edit: 在 `let rec print_sexpr sexpr =` 中添加：

```ocaml
let rec print_sexpr sexpr =
  match sexpr with
  | ...
  | Date d ->
      print_string (CalendarLib.Date.to_string d)
  | ...
```

**Step 4: 更新 lib/object/dune**

```lisp
(library
 (name mlisp_object)
 (public_name mlisp.object)
 (modules object)
 (libraries core ocolor ppx_string calendar))
```

**Step 5: 提交**

```bash
git add lib/object/object.ml lib/object/dune
git commit -m "feat: add Date type to lobject"
```

---

### Task 6: 创建 Date 模块绑定

**Files:**
- Create: `lib/primitives/date_binding.ml`

**Step 1: 创建 date_binding.ml**

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core
open CalendarLib
open Module_builder
open Converter

(** Date Module Binding - wraps CalendarLib.Date *)

module Date = struct
  let name = "Date"

  let bindings = [
    "parse-fhir", (fun args ->
      match args with
      | [Object.String date_str] ->
          begin try
            let parts = String.split ~on:'-' date_str in
            match parts with
            | [year; month; day] ->
                let y = int_of_string year in
                let m = int_of_string month in
                let d = int_of_string day in
                Object.Date (Date.make y m d)
            | _ ->
                raise (Errors.Runtime_error_exn
                  (Errors.Parse_error "Invalid FHIR date format (expected YYYY-MM-DD)"))
          with
          | _ ->
              raise (Errors.Runtime_error_exn
                (Errors.Parse_error "Invalid FHIR date format"))
      end
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date.parse-fhir string)")));

    "parse", (fun args ->
      match args with
      | [Object.String date_str] ->
          begin try
            Object.Date (Date.from_string date_str)
          with
          | _ ->
              raise (Errors.Runtime_error_exn
                (Errors.Parse_error "Invalid ISO date format"))
          end
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date.parse string)")));

    "today", (fun args ->
      match args with
      | [] -> Object.Date (Date.today ())
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Date.today)")));

    "format", (fun args ->
      match args with
      | [Object.Date date] ->
          Object.String (Date.to_string date)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date.format date)")));

    "age", (fun args ->
      match args with
      | [Object.Date birth] ->
          let today = Date.today () in
          let days = Date.days_between birth today in
          Object.Fixnum (days / 365)
      | [Object.String birth_str] ->
          begin try
            let birth = Date.from_string birth_str in
            let today = Date.today () in
            let days = Date.days_between birth today in
            Object.Fixnum (days / 365)
          with
          | _ ->
              raise (Errors.Runtime_error_exn
                (Errors.Parse_error "Invalid birth date"))
          end
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date.age birth-date)")));

    "diff-days", (fun args ->
      match args with
      | [Object.Date d1; Object.Date d2] ->
          Object.Fixnum (Date.days_between d1 d2)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date.diff-days date1 date2)")));

    "add-days", (fun args ->
      match args with
      | [Object.Date date; Object.Fixnum days] ->
          Object.Date (Date.add_days date days)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date.add-days date days)")));

    "subtract-days", (fun args ->
      match args with
      | [Object.Date date; Object.Fixnum days] ->
          Object.Date (Date.add_days date (-days))
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date.subtract-days date days)")));

    "<?", (fun args ->
      match args with
      | [Object.Date d1; Object.Date d2] ->
          Object.Boolean (Date.compare d1 d2 < 0)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date<? date1 date2)")));

    "<=?", (fun args ->
      match args with
      | [Object.Date d1; Object.Date d2] ->
          Object.Boolean (Date.compare d1 d2 <= 0)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date<=? date1 date2)")));

    ">?", (fun args ->
      match args with
      | [Object.Date d1; Object.Date d2] ->
          Object.Boolean (Date.compare d1 d2 > 0)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date>? date1 date2)")));

    ">=?", (fun args ->
      match args with
      | [Object.Date d1; Object.Date d2] ->
          Object.Boolean (Date.compare d1 d2 >= 0)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date>=? date1 date2)")));

    "=", (fun args ->
      match args with
      | [Object.Date d1; Object.Date d2] ->
          Object.Boolean (Date.compare d1 d2 = 0)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date= date1 date2)")));

    "year", (fun args ->
      match args with
      | [Object.Date date] ->
          Object.Fixnum (Date.year date)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date.year date)")));

    "month", (fun args ->
      match args with
      | [Object.Date date] ->
          Object.Fixnum (Date.month date)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date.month date)")));

    "day", (fun args ->
      match args with
      | [Object.Date date] ->
          Object.Fixnum (Date.day date)
      | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error "(Date.day date)")));
  ]
end

include (Date : Module_sig)
```

**Step 2: 注册 Date 模块**

Modify: `lib/primitives/basis.ml`

```ocaml
let register_library_modules basis_env =
  register_all_modules [
    (module Json : Module_sig);
    (module Date : Module_sig);
  ] basis_env
```

**Step 3: 创建测试**

Create: `test/31_date_module.mlisp`

```lisp
;; Test 1: Date.parse-fhir
(define birth (Date.parse-fhir "1955-07-23"))
(print birth)

;; Test 2: Date.format
(print (Date.format birth))

;; Test 3: Date.age
(print (Date.age birth))

;; Test 4: Date.today
(define today (Date.today))
(print (Date.format today))

;; Test 5: Date arithmetic
(define tomorrow (Date.add-days today 1))
(print (Date.format tomorrow))

(define yesterday (Date.subtract-days today 1))
(print (Date.format yesterday))

;; Test 6: Date.diff-days
(define d1 (Date.parse "2024-01-01"))
(define d2 (Date.parse "2024-01-15"))
(print (Date.diff-days d1 d2))

;; Test 7: Date comparisons
(print (Date<? d1 d2))
(print (Date>? d2 d1))
(print (Date= d1 d1))

;; Test 8: Date components
(define test-date (Date.parse "2024-06-15"))
(print (Date.year test-date))
(print (Date.month test-date))
(print (Date.day test-date))

;; Test 9: Age from string
(print (Date.age "1990-05-20"))

(print "All Date module tests passed!")
```

**Step 4: 运行测试**

Run: `dune exec mlisp -- test/31_date_module.mlisp`

**Step 5: 提交**

```bash
git add lib/primitives/date_binding.ml lib/primitives/basis.ml test/31_date_module.mlisp
git commit -m "feat: add Date module binding"
```

---

## Phase 5: String 模块绑定

### Task 7: 创建 String 扩展模块绑定

**Files:**
- Create: `lib/primitives/string_ext_binding.ml`

**Step 1: 创建 string_ext_binding.ml**

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core
open Module_builder

(** String Extended Module Binding *)

module String_ext = struct
  let name = "String"

  let bindings = [
    "length", (fun args ->
      match args with
      | [Object.String s] -> Object.Fixnum (String.length s)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String.length string)")));

    "split", (fun args ->
      match args with
      | [Object.String s; Object.String sep] ->
          let parts = String.split ~on:sep s in
          List.fold_right parts ~init:Object.Nil ~f:(fun part acc ->
            Object.Pair (Object.String part, acc))
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String.split string separator)")));

    "join", (fun args ->
      match args with
      | [Object.Pair _ as list; Object.String sep] ->
          let rec extract_strings = function
            | Object.Nil -> []
            | Object.Pair (Object.String s, rest) -> s :: extract_strings rest
            | Object.Pair (_, rest) -> extract_strings rest
            | _ -> []
          in
          let strings = extract_strings list in
          Object.String (String.concat ~sep strings)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String.join list-of-strings separator)")));

    "trim", (fun args ->
      match args with
      | [Object.String s] -> Object.String (String.strip s)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String.trim string)")));

    "contains?", (fun args ->
      match args with
      | [Object.String s; Object.String pattern] ->
          Object.Boolean (String.is_substring pattern ~within:s)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String.contains? string pattern)")));

    "replace", (fun args ->
      match args with
      | [Object.String s; Object.String pattern; Object.String replacement] ->
          Object.String (String.replace_all s ~pattern ~replacement)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String.replace string pattern replacement)")));

    "upper", (fun args ->
      match args with
      | [Object.String s] -> Object.String (String.uppercase s)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String.upper string)")));

    "lower", (fun args ->
      match args with
      | [Object.String s] -> Object.String (String.lowercase s)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String.lower string)")));

    "<?", (fun args ->
      match args with
      | [Object.String a; Object.String b] ->
          Object.Boolean (String.compare a b < 0)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String<? a b)")));

    ">?", (fun args ->
      match args with
      | [Object.String a; Object.String b] ->
          Object.Boolean (String.compare a b > 0)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String>? a b)")));

    "=", (fun args ->
      match args with
      | [Object.String a; Object.String b] ->
          Object.Boolean (String.equal a b)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String= a b)")));

    "concat", (fun args ->
      match args with
      | [Object.String a; Object.String b] ->
          Object.String (a ^ b)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String.concat a b)")));

    "substring", (fun args ->
      match args with
      | [Object.String s; Object.Fixnum start; Object.Fixnum len] ->
          if start >= 0 && len >= 0 && start + len <= String.length s then
            Object.String (String.sub s ~pos:start ~len:len)
          else
            raise (Errors.Runtime_error_exn (Errors.Index_error "Substring out of bounds"))
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(String.substring string start length)")));
  ]
end

include (String_ext : Module_sig)
```

**Step 2: 注册 String 模块**

Modify: `lib/primitives/basis.ml`

**Step 3: 创建测试**

Create: `test/32_string_module.mlisp`

```lisp
;; Test: String.length
(print (String.length "hello"))

;; Test: String.split
(define parts (String.split "a,b,c" ","))
(print parts)

;; Test: String.join
(print (String.join '("x" "y" "z") "-"))

;; Test: String.trim
(print (String.trim "  hello  "))

;; Test: String.contains?
(print (String.contains? "hello world" "world"))
(print (String.contains? "hello" "xyz"))

;; Test: String.replace
(print (String.replace "hello world" "world" "MLisp"))

;; Test: String.upper/lower
(print (String.upper "hello"))
(print (String.lower "HELLO"))

;; Test: String comparisons
(print (String<? "apple" "banana"))
(print (String>? "zebra" "apple"))
(print (String= "test" "test"))

;; Test: String.concat
(print (String.concat "hello" " world"))

;; Test: String.substring
(print (String.substring "hello" 1 3))

(print "All String module tests passed!")
```

**Step 4: 运行测试**

Run: `dune exec mlisp -- test/32_string_module.mlisp`

**Step 5: 提交**

```bash
git add lib/primitives/string_ext_binding.ml lib/primitives/basis.ml test/32_string_module.mlisp
git commit -m "feat: add String module binding"
```

---

## Phase 6: Set 模块绑定

### Task 8: 创建 Set 模块绑定

**Files:**
- Create: `lib/primitives/set_binding.ml`

**Step 1: 创建 set_binding.ml**

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core
open Module_builder

(** Set Module Binding - Collection operations *)

module Set = struct
  let name = "Set"

  (** Helper: Convert Lisp list to OCaml list *)
  let rec to_ocaml_list = function
    | Object.Nil -> []
    | Object.Pair (h, t) -> h :: to_ocaml_list t
    | x -> [x]

  (** Helper: Convert OCaml list to Lisp list *)
  let rec to_lisp_list = function
    | [] -> Object.Nil
    | h :: t -> Object.Pair (h, to_lisp_list t)

  (** Helper: Value equality for Lisp objects *)
  let lobject_equal a b =
    match a, b with
    | Object.Nil, Object.Nil -> true
    | Object.Boolean a, Object.Boolean b -> a = b
    | Object.Fixnum a, Object.Fixnum b -> a = b
    | Object.Float a, Object.Float b -> a = b
    | Object.String a, Object.String b -> String.equal a b
    | Object.Symbol a, Object.Symbol b -> String.equal a b
    | _ -> a == b

  (** Helper: Check if value exists in list *)
  let rec mem lst value =
    List.exists lst ~f:(fun x -> lobject_equal x value)

  let bindings = [
    "unique", (fun args ->
      match args with
      | [Object.Pair _ | Object.Nil as lst] ->
          let rec dedup acc = function
            | Object.Nil -> to_lisp_list (List.rev acc)
            | Object.Pair (h, t) ->
                if mem acc h then dedup acc t
                else dedup (h :: acc) t
            | x -> to_lisp_list (List.rev [x])
          in
          dedup [] lst
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Set.unique list)")));

    "union", (fun args ->
      match args with
      | [Object.Pair _ | Object.Nil as list1; Object.Pair _ | Object.Nil as list2] ->
          let combined = to_ocaml_list list1 @ to_ocaml_list list2 in
          (match (List.find combined ~f:(fun _ -> true)) with
          | Some first ->
              let rec dedup acc = function
                | [] -> to_lisp_list (List.rev acc)
                | h :: t ->
                    if mem acc h then dedup acc t
                    else dedup (h :: acc) t
              in
              dedup [] combined
          | None -> Object.Nil)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Set.union list1 list2)")));

    "intersection", (fun args ->
      match args with
      | [Object.Pair _ | Object.Nil as list1; Object.Pair _ | Object.Nil as list2] ->
          let lst2 = to_ocaml_list list2 in
          let rec intersect acc = function
            | Object.Nil -> to_lisp_list (List.rev acc)
            | Object.Pair (h, t) ->
                if mem lst2 h then intersect (h :: acc) t
                else intersect acc t
            | h ->
                if mem lst2 h then to_lisp_list (List.rev (h :: acc))
                else to_lisp_list (List.rev acc)
          in
          intersect [] list1
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Set.intersection list1 list2)")));

    "difference", (fun args ->
      match args with
      | [Object.Pair _ | Object.Nil as list1; Object.Pair _ | Object.Nil as list2] ->
          let lst2 = to_ocaml_list list2 in
          let rec difference acc = function
            | Object.Nil -> to_lisp_list (List.rev acc)
            | Object.Pair (h, t) ->
                if mem lst2 h then difference acc t
                else difference (h :: acc) t
            | h ->
                if mem lst2 h then to_lisp_list (List.rev acc)
                else to_lisp_list (List.rev (h :: acc))
          in
          difference [] list1
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Set.difference list1 list2)")));

    "filter", (fun args ->
      match args with
      | [Object.Primitive (_, pred); Object.Pair _ | Object.Nil as lst] ->
          let rec filter acc = function
            | Object.Nil -> to_lisp_list (List.rev acc)
            | Object.Pair (h, t) ->
                (match pred [h] with
                | Object.Boolean true -> filter (h :: acc) t
                | _ -> filter acc t)
          in
          filter [] lst
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Set.filter predicate list)")));

    "map", (fun args ->
      match args with
      | [Object.Primitive (_, fn); Object.Pair _ | Object.Nil as lst] ->
          let rec map acc = function
            | Object.Nil -> List.rev acc
            | Object.Pair (h, t) -> map (fn [h] :: acc) t
          in
          to_lisp_list (map [] lst)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Set.map function list)")));

    "reduce", (fun args ->
      match args with
      | [Object.Primitive (_, fn); init; Object.Pair _ | Object.Nil as lst] ->
          let rec reduce acc = function
            | Object.Nil -> acc
            | Object.Pair (h, t) -> reduce (fn [acc; h]) t
          in
          reduce init lst
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Set.reduce function initial list)")));

    "forall?", (fun args ->
      match args with
      | [Object.Primitive (_, pred); Object.Pair _ | Object.Nil as lst] ->
          let rec check = function
            | Object.Nil -> true
            | Object.Pair (h, t) ->
                (match pred [h] with
                | Object.Boolean true -> check t
                | _ -> false)
          in
          Object.Boolean (check lst)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Set.forall? predicate list)")));

    "exists?", (fun args ->
      match args with
      | [Object.Primitive (_, pred); Object.Pair _ | Object.Nil as lst] ->
          let rec check = function
            | Object.Nil -> false
            | Object.Pair (h, t) ->
                (match pred [h] with
                | Object.Boolean true -> true
                | _ -> check t)
          in
          Object.Boolean (check lst)
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Set.exists? predicate list)")));
  ]
end

include (Set : Module_sig)
```

**Step 2: 注册 Set 模块**

Modify: `lib/primitives/basis.ml`

**Step 3: 创建测试**

Create: `test/33_set_module.mlisp`

```lisp
;; Test: Set.unique
(print (Set.unique '(1 2 2 3 3 3 4)))

;; Test: Set.union
(define list1 '(1 2 3))
(define list2 '(3 4 5))
(print (Set.union list1 list2))

;; Test: Set.intersection
(print (Set.intersection list1 list2))

;; Test: Set.difference
(print (Set.difference list1 list2))

;; Test: Set.filter
(define positive? (lambda (x) (> x 0)))
(print (Set.filter positive? '(-1 2 -3 4 -5)))

;; Test: Set.map
(print (Set.map (lambda (x) (* x 2)) '(1 2 3)))

;; Test: Set.reduce
(print (Set.reduce (lambda (acc x) (+ acc x)) 0 '(1 2 3 4)))

;; Test: Set.forall?
(print (Set.forall? positive? '(1 2 3 4)))
(print (Set.forall? positive? '(1 -2 3)))

;; Test: Set.exists?
(print (Set.exists? positive? '(-1 -2 3)))
(print (Set.exists? positive? '(-1 -2 -3)))

(print "All Set module tests passed!")
```

**Step 4: 运行测试**

Run: `dune exec mlisp -- test/33_set_module.mlisp`

**Step 5: 提交**

```bash
git add lib/primitives/set_binding.ml lib/primitives/basis.ml test/33_set_module.mlisp
git commit -m "feat: add Set module binding"
```

---

## Phase 7: HTTP 模块绑定

### Task 9: 创建 HTTP 模块绑定

**Files:**
- Create: `lib/primitives/http_binding.ml`

**Step 1: 创建 http_binding.ml**

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core
open Cohttp
open Cohttp_lwt_unix
open Lwt
open Module_builder

(** HTTP Module Binding - wraps Cohttp *)

module Http = struct
  let name = "Http"

  (** Helper: Convert Lisp list of pairs to query params *)
  let rec extract_params = function
    | Object.Nil -> []
    | Object.Pair (Object.Pair (Object.String k, Object.String v), rest) ->
      (k, v) :: extract_params rest
    | Object.Pair (_, rest) -> extract_params rest
    | _ -> []

  let bindings = [
    "get", (fun args ->
      match args with
      | [Object.String url] ->
          Lwt_main.run (
            Client.call ~headers:(Header.init ()) `GET url
            >>= fun (_, body) ->
            Cohttp_lwt.Body.to_string body
            >|= fun response_body ->
              Object.String response_body
          )
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Http.get url-string)")));

    "post", (fun args ->
      match args with
      | [Object.String url; Object.String body] ->
          Lwt_main.run (
            Client.call
              ~headers:(Header.init ())
              ~body:(Cohttp_lwt.Body.of_string body)
              `POST url
            >>= fun (_, response_body) ->
            Cohttp_lwt.Body.to_string response_body
            >|= fun response ->
              Object.String response
          )
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Http.post url-string body-string)")));

    "put", (fun args ->
      match args with
      | [Object.String url; Object.String body] ->
          Lwt_main.run (
            Client.call
              ~headers:(Header.init ())
              ~body:(Cohttp_lwt.Body.of_string body)
              `PUT url
            >>= fun (_, response_body) ->
            Cohttp_lwt.Body.to_string response_body
            >|= fun response ->
              Object.String response
          )
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Http.put url-string body-string)")));

    "delete", (fun args ->
      match args with
      | [Object.String url] ->
          Lwt_main.run (
            Client.call ~headers:(Header.init ()) `DELETE url
            >>= fun (_, body) ->
            Cohttp_lwt.Body.to_string body
            >|= fun response_body ->
              Object.String response_body
          )
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Http.delete url-string)")));

    "urlencode", (fun args ->
      match args with
      | [Object.Pair _ as params] ->
          let pairs = extract_params params in
          let encoded = String.concat ~sep:"&" (List.map pairs ~f:(fun (k, v) ->
            [%string "%{Cohttp.Uri.encode k}=%{Cohttp.Uri.encode v}"]
          )) in
          Object.String encoded
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Http.urlencode ((key . value) ...))")));

    "build-url", (fun args ->
      match args with
      | [Object.String base; Object.Pair _ as params] ->
          let encoded = match (fun args -> match args with [Object.Pair _ as params] -> Object.String (match (fun args -> match args with [Object.String s] -> s | _ -> "") [params]) | _ -> "") [params] with
          | Object.String s -> s
          | _ -> ""
          in
          Object.String (if String.is_empty encoded then base else [%string "%{base}?%{encoded}"])
      | [Object.String base; Object.Nil] ->
          Object.String base
      | _ -> raise (Errors.Parse_error_exn (Errors.Type_error "(Http.build-url base-url params-list)")));
  ]
end

include (Http : Module_sig)
```

**Step 2: 注册 Http 模块**

Modify: `lib/primitives/basis.ml`

**Step 3: 创建测试**

Create: `test/34_http_module.mlisp`

```lisp
;; Test: Http.urlencode
(print (Http.urlencode '(("name" . "John Doe") ("age" . "30"))))

;; Test: Http.build-url
(print (Http.build-url "https://api.example.com/search" '(("q" . "lisp") ("limit" . "10"))))

;; Test: Http.build-url with empty params
(print (Http.build-url "https://example.com" '()))

;; Note: Full HTTP tests require network access
;; (define response (Http.get "https://jsonplaceholder.typicode.com/posts/1"))
;; (print response)

(print "Http module loaded successfully!")
```

**Step 4: 运行测试**

Run: `dune exec mlisp -- test/34_http_module.mlisp`

**Step 5: 提交**

```bash
git add lib/primitives/http_binding.ml lib/primitives/basis.ml test/34_http_module.mlisp
git commit -m "feat: add Http module binding"
```

---

## Phase 8: 点号语法糖宏

### Task 10: 创建点号访问语法糖宏

**Files:**
- Create: `lib/stdlib/syntax.mlisp`

**Step 1: 创建语法糖宏库**

Create: `lib/stdlib/syntax.mlisp`

```lisp
;; MLisp Syntax Sugar Library
;; Provides convenient macros for accessing module methods

;; Basic module method call: (module..method arg1 arg2 ...)
;; Expands to: (record-get module "method" arg1 arg2 ...)
(defmacro .. (module method &rest args)
  `(record-get ,module ,(symbol-concat "" method) ,@args))

;; Alternative: using dot notation (requires symbol with dot)
;; (Json/parse str) -> (record-get Json "parse" str)
(defmacro / (module method &rest args)
  `(record-get ,module ,(symbol-concat "" method) ,@args))

;; Pipeline operator: (x |> f) -> (f x)
;; (x |> f |> g) -> (g (f x))
(defmacro |> (value &rest functions)
  (if (null? functions)
      value
      `(,(car functions) ,value ,@(cdr functions))))

;; Thread-first: (-> x f g h) -> (h (g (f x)))
(defmacro -> (value &rest functions)
  (if (null? functions)
      value
      (let ((fst (car functions))
            (rest (cdr functions)))
        (if (null? rest)
            `(,fst ,value)
            `(-> (,fst ,value) ,@rest)))))

;; Thread-last: (->> x f g h) -> (f (g (h x)))
(defmacro ->> (value &rest functions)
  (if (null? functions)
      value
      (let ((fst (car functions))
            (rest (cdr functions)))
        (if (null? rest)
            `(,fst ,value)
            `(->> (,fst ,value) ,@rest)))))

;; 让操作符: (let* ((x (expr1)) (y (expr2))) body)
;; 这是 Core MLisp 的 let* 的别名

```

**Step 2: 更新标准库加载器**

Modify: `lib/stdlib/stdlib_loader.ml`

在 `load_metadata` 中添加 "syntax" 到默认模块列表：

```ocaml
let modules = get_list_value "stdlib-modules" [ "core"; "list"; "io"; "assert"; "syntax" ] in
```

**Step 3: 创建语法糖测试**

Create: `test/35_syntax.mlisp`

```lisp
(load "stdlib/syntax.mlisp")

;; Test: .. operator for module method access
(define obj (Json..parse "{\"x\": 10}"))
(print obj)

(print (Json..stringify obj))

;; Test: nested path
(define patient (Json.parse "{\"name\": \"Alice\", \"age\": 30}"))
(print (Json..get patient "name"))

;; Test: pipeline operator
(define result (-> "  hello  " String..trim String..upper))
(print result)

;; Test: chained pipeline
(define result2 (->> '(1 2 2 3) Set..unique Set..map (lambda (x) (* x 2))))
(print result2)

(print "All syntax sugar tests passed!")
```

**Step 4: 运行测试**

Run: `dune exec mlisp -- test/35_syntax.mlisp`

**Step 5: 提交**

```bash
git add lib/stdlib/syntax.mlisp lib/stdlib/stdlib_loader.ml test/35_syntax.mlisp
git commit -m "feat: add dot notation and pipeline operator macros"
```

---

## Phase 9: 集成测试

### Task 11: 创建完整的临床研究示例测试

**Files:**
- Create: `test/40_clinical_demo.mlisp`

**Step 1: 创建综合示例**

```lisp
;; Clinical Research Screening Demo
;; Demonstrates using MLisp with OCaml library bindings for patient screening

(load "stdlib/syntax.mlisp")

;; Helper function to check if patient meets criteria
(define meets-inclusion-criteria (lambda (patient)
  (let* (
    ;; Extract birth date and calculate age
    (birth-date (Json..get patient "birthDate"))
    (age (Date..age (Date..parse-fhir birth-date)))

    ;; Get conditions
    (conditions (Json..get patient "condition"))
    (has-diabetes (Set..exists? (lambda (c)
      (String..contains? (Json..get c "code.coding.0.code") "E11")
    ) conditions))

    ;; Check medications
    (medications (Json..get patient "medication"))
    (on-insulin (Set..exists? (lambda (m)
      (String..contains? (Json..get m "medication.code.coding.0.code") "insulin")
    ) medications))
    )

    ;; Inclusion: 18-75 years old, has type 2 diabetes
    ;; Exclusion: on insulin therapy
    (and (>= age 18)
         (<= age 75)
         has-diabetes
         (not on-insulin))
  )))

;; Mock patient data
(define patient1 (Json..parse "{
  \"resourceType\": \"Patient\",
  \"birthDate\": \"1960-05-15\",
  \"condition\": [
    {\"code\": {\"coding\": [{\"code\": \"E11\"}]}}
  ],
  \"medication\": []
}"))

(define patient2 (Json..parse "{
  \"resourceType\": \"Patient\",
  \"birthDate\": \"1995-03-20\",
  \"condition\": [
    {\"code\": {\"coding\": [{\"code\": \"E11\"}]}}
  ],
  \"medication\": [
    {\"medication\": {\"code\": {\"coding\": [{\"code\": \"insulin\"}]}}}
  ]
}"))

(define patient3 (Json..parse "{
  \"resourceType\": \"Patient\",
  \"birthDate\": \"1950-01-10\",
  \"condition\": [
    {\"code\": {\"coding\": [{\"code\": \"I10\"}]}}
  ],
  \"medication\": []
}"))

;; Screen patients
(print "Patient 1 meets criteria:")
(print (meets-inclusion-criteria patient1))

(print "Patient 2 meets criteria:")
(print (meets-inclusion-criteria patient2))

(print "Patient 3 meets criteria:")
(print (meets-inclusion-criteria patient3))

;; Calculate summary
(define patients (list patient1 patient2 patient3))
(define eligible-patients (Set..filter meets-inclusion-criteria patients))

(print "Total patients:")
(print (length patients))

(print "Eligible patients:")
(print (length eligible-patients))

(print "Clinical screening demo completed!")
```

**Step 2: 运行综合测试**

Run: `dune exec mlisp -- test/40_clinical_demo.mlisp`

**Step 3: 提交**

```bash
git add test/40_clinical_demo.mlisp
git commit -m "test: add clinical research screening demo"
```

---

## 验收标准

所有 Phase 完成后，以下代码应该能正常工作：

```lisp
(load "stdlib/syntax.mlisp")

;; 模块点号访问
(Json..parse "{\"a\": 1}")
(Date..today)
(String..split "a,b,c" ",")
(Set..unique '(1 1 2 3))
(Http..build-url "https://api.com" '(("q" . "test")))

;; 管道操作符
(-> "  hello  " String..trim String..upper)

;; 临床研究筛选
(-> patient-json
    Json..parse
    (lambda (p) (Json..get p "birthDate"))
    Date..parse-fhir
    Date..age)
```

---

## 实施顺序

按以下顺序逐步实施：

1. **Task 1**: 添加依赖 (yojson, calendar, cohttp)
2. **Task 2**: 创建类型转换器
3. **Task 3**: 创建模块构建器
4. **Task 4**: JSON 模块绑定
5. **Task 5-6**: Date 模块绑定
6. **Task 7**: String 模块绑定
7. **Task 8**: Set 模块绑定
8. **Task 9**: HTTP 模块绑定
9. **Task 10**: 语法糖宏
10. **Task 11**: 集成测试示例

每完成一个 Task，运行：

```bash
./run_tests.sh '3[0-9]*.mlisp' '4[0-9]*.mlisp'
```
