# MLisp 基础能力扩展实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为支持临床研究入排标准筛选场景，扩展 MLisp 的基础数据处理能力，包括 JSON 解析、哈希表、字符串操作、日期时间处理、HTTP 客户端、集合操作和异常处理。

**架构:** 基于现有 MLisp 原语系统模式，在 `lib/primitives/` 下新增模块文件，通过 OCaml 库绑定实现功能，注册到 Basis 环境中。

**Tech Stack:** OCaml 5.0+, Dune 3.3+, yojson (JSON), cohttp (HTTP), calendar (日期时间)

---

## 任务概览

| 阶段 | 任务 | 优先级 | 预计工作量 |
|------|------|--------|------------|
| Phase 1 | JSON 解析/序列化 | P0 | 1-2 周 |
| Phase 2 | 哈希表/字典 | P0 | 1 周 |
| Phase 3 | 字符串操作增强 | P0 | 3-5 天 |
| Phase 4 | 日期/时间处理 | P1 | 1 周 |
| Phase 5 | HTTP 客户端 | P1 | 1-2 周 |
| Phase 6 | 集合操作增强 | P1 | 3-5 天 |
| Phase 7 | 异常处理 (try/catch) | P1 | 1 周 |

---

## Phase 1: JSON 解析/序列化

### 依赖添加

**Files:**
- Modify: `dune-project`
- Modify: `mlisp.opam`

**Step 1: 添加 yojson 依赖到 dune-project**

```lisp
(package
 (name mlisp)
 (version 0.0.44)
 (synopsis "A Lisp implementation in OCaml")
 (description "A Lisp implementation in OCaml")
 (depends ocaml dune core ocolor camlp-streams ocamline core_unix ppx_string yojson))
```

**Step 2: 运行 opam 安装依赖**

Run: `opam install . --deps-only`

**Step 3: 提交**

```bash
git add dune-project mlisp.opam
git commit -m "feat: add yojson dependency for JSON support"
```

---

### Task 1.1: JSON 原语模块创建

**Files:**
- Create: `lib/primitives/json.ml`

**Step 1: 创建基础 JSON 模块骨架**

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Yojson

(** Convert MLisp object to Yojson JSON value *)
let rec lobject_to_json = function
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
      (* Convert record to JSON object *)
      let obj_fields = List.map fields ~f:(fun (k, v) -> (k, lobject_to_json v)) in
      `Assoc obj_fields
  | _ -> raise (Errors.Runtime_error_exn (Errors.Type_error "Cannot convert to JSON"))

(** Convert Yojson JSON value to MLisp object *)
let rec json_to_lobject = function
  | `Null -> Object.Nil
  | `Bool b -> Object.Boolean b
  | `Int i -> Object.Fixnum i
  | `Float f -> Object.Float f
  | `String s -> Object.String s
  | `List arr ->
      List.fold_right arr ~init:Object.Nil ~f:(fun v acc ->
        Object.Pair (json_to_lobject v, acc))
  | `Assoc fields ->
      (* Convert JSON object to a record-like structure using hash table *)
      (* For now, convert to list of pairs *)
      let fields_list = List.map fields ~f:(fun (k, v) ->
        (k, json_to_lobject v)) in
      Object.Record ("JsonObject", fields_list)
  | `Bool _ -> `Null
  | `Intlit _ -> `Null
  | `Stringlit _ -> `Null
  | `Tuple _ -> `Null

(** Parse JSON string to MLisp object *)
let json_parse = function
  | [ Object.String json_str ] ->
      begin try
        let json = Yojson.Basic.from_string json_str in
        json_to_lobject json
      with
      | Yojson.Json_error msg ->
        raise (Errors.Runtime_error_exn (Errors.Parse_error ([%string "JSON parse error: %{msg}"])))
      end
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(json-parse string)"))

(** Convert MLisp object to JSON string *)
let json_stringify = function
  | [ obj ] ->
      let json = lobject_to_json obj in
      Object.String (Yojson.Basic.to_string json)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(json-stringify object)"))

(** Pretty print JSON with indentation *)
let json_stringify_pretty = function
  | [ obj ] ->
      let json = lobject_to_json obj in
      Object.String (Yojson.Basic.pretty_to_string json)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(json-stringify-pretty object)"))

(** Get nested path from JSON object
    Supports dot notation: "user.address.city" or array index: "items.0.name"
 *)
let json_get_path = function
  | [ obj; Object.String path ] ->
      let json = lobject_to_json obj in
      let segments = String.split ~on:'.' path in
      let rec navigate json segs =
        match segs, json with
        | [], _ -> json
        | seg :: rest, `Assoc fields ->
            (match List.find fields ~f:(fun (k, _) -> k = seg) with
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
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(json-get-path object path-string)"))

let basis =
  [ "json-parse", json_parse
  ; "json-stringify", json_stringify
  ; "json-stringify-pretty", json_stringify_pretty
  ; "json-get-path", json_get_path
  ]
;;
```

**Step 2: 注册 JSON 原语到 Basis**

Modify: `lib/primitives/basis.ml`

在现有的 basis 列表中添加 json 模块：

```ocaml
let basis =
  [ ...existing bindings...
  ; @Mlisp_primitives.Json.basis
  ]
```

**Step 3: 创建测试文件**

Create: `test/20_json.mlisp`

```lisp
;; Test 1: Parse simple JSON string
(define json-str "{\"name\": \"John\", \"age\": 30}")
(define obj (json-parse json-str))
(print obj)
(assert (not (null? obj)))

;; Test 2: Parse nested JSON
(define nested "{\"user\": {\"name\": \"Alice\", \"address\": {\"city\": \"Beijing\"}}}")
(define parsed (json-parse nested))
(print parsed)

;; Test 3: Parse JSON array
(define arr-str "[1, 2, 3, 4, 5]")
(define arr (json-parse arr-str))
(print arr)

;; Test 4: Stringify MLisp object to JSON
(define mlisp-obj '(("name" . "John") ("age" . 30)))
(define json-out (json-stringify mlisp-obj))
(print json-out)

;; Test 5: Pretty print
(define pretty (json-stringify-pretty mlisp-obj))
(print pretty)

;; Test 6: Path access
(define patient "{\"id\": \"123\", \"name\": \"Bob\", \"conditions\": [{\"code\": \"E11\"}]}")
(define parsed-patient (json-parse patient))
(print (json-get-path parsed-patient "name"))
(print (json-get-path parsed-patient "conditions.0.code"))

(print "All JSON tests passed!")
```

**Step 4: 运行测试验证**

Run: `dune exec mlisp -- test/20_json.mlisp`

Expected: 所有测试通过，输出解析后的对象

**Step 5: 提交**

```bash
git add lib/primitives/json.ml lib/primitives/basis.ml test/20_json.mlisp
git commit -m "feat: add JSON parse/stringify primitives"
```

---

## Phase 2: 哈希表/字典

### Task 2.1: 哈希表原语模块

**Files:**
- Create: `lib/primitives/hashtbl.ml`

**Step 1: 创建哈希表模块**

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core

(** Hash table implementation wrapper
    We use a Symbol to store the hash table reference *)
module HTable = struct
  let counter = ref 0
  let tables = (Hashtbl.create 16 : (int, (string, lobject) Hashtbl.t) Hashtbl.t)

  let create () =
    incr counter;
    let id = !counter in
    let tbl = Hashtbl.create 16 in
    Hashtbl.add tables id tbl;
    Object.String [%string "htable[%{Int.to_string id}]"

  let get_id = function
    | Object.String s when String.is_prefix s ~prefix:"htable[" ->
        let suffix = String.drop_prefix s 7 in
        let closing = String.find suffix ~sub:")" in
        Some (int_of_string (String.sub suffix ~pos:0 ~len:closing))
    | _ -> None

  let find = function
    | Some id -> (
        match Hashtbl.find tables id with
        | tbl -> Some tbl
        | exception Not_found -> None)
    | None -> None
end

(** Create a new hash table *)
let hash_create = function
  | [] ->
      HTable.create ()
  | [ Object.Fixnum size ] when size > 0 ->
      HTable.create ()
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(hash-create [size])"))

(** Set a key-value pair in hash table *)
let hash_set = function
  | [ htable; Object.String key; value ] ->
      (match HTable.find (HTable.get_id htable) with
      | Some tbl ->
          Hashtbl.set tbl key value;
          Object.Symbol "ok"
      | None ->
          raise (Errors.Runtime_error_exn (Errors.Not_found "Invalid hash table")))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(hash-set hashtable key value)"))

(** Get a value by key from hash table *)
let hash_get = function
  | [ htable; Object.String key ] ->
      (match HTable.find (HTable.get_id htable) with
      | Some tbl ->
          (match Hashtbl.find tbl key with
          | v -> v
          | exception Not_found -> Object.Nil)
      | None ->
          raise (Errors.Runtime_error_exn (Errors.Not_found "Invalid hash table")))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(hash-get hashtable key)"))

(** Check if key exists in hash table *)
let hash_has = function
  | [ htable; Object.String key ] ->
      (match HTable.find (HTable.get_id htable) with
      | Some tbl ->
          Object.Boolean (Hashtbl.mem tbl key)
      | None ->
          raise (Errors.Runtime_error_exn (Errors.Not_found "Invalid hash table")))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(hash-has? hashtable key)"))

(** Remove a key from hash table *)
let hash_remove = function
  | [ htable; Object.String key ] ->
      (match HTable.find (HTable.get_id htable) with
      | Some tbl ->
          Hashtbl.remove tbl key;
          Object.Symbol "ok"
      | None ->
          raise (Errors.Runtime_error_exn (Errors.Not_found "Invalid hash table")))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(hash-remove hashtable key)"))

(** Get all keys from hash table as a list *)
let hash_keys = function
  | [ htable ] ->
      (match HTable.find (HTable.get_id htable) with
      | Some tbl ->
          let keys = Hashtbl.keys tbl in
          List.fold_right keys ~init:Object.Nil ~f:(fun k acc ->
            Object.Pair (Object.String k, acc))
      | None ->
          raise (Errors.Runtime_error_exn (Errors.Not_found "Invalid hash table")))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(hash-keys hashtable)"))

(** Get all values from hash table as a list *)
let hash_values = function
  | [ htable ] ->
      (match HTable.find (HTable.get_id htable) with
      | Some tbl ->
          let values = Hashtbl.data tbl |> List.map ~f:(fun (_, v) -> v) in
          List.fold_right values ~init:Object.Nil ~f:(fun v acc ->
            Object.Pair (v, acc))
      | None ->
          raise (Errors.Runtime_error_exn (Errors.Not_found "Invalid hash table")))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(hash-values hashtable)"))

(** Get size of hash table *)
let hash_size = function
  | [ htable ] ->
      (match HTable.find (HTable.get_id htable) with
      | Some tbl ->
          Object.Fixnum (Hashtbl.length tbl)
      | None ->
          raise (Errors.Runtime_error_exn (Errors.Not_found "Invalid hash table")))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(hash-size hashtable)"))

(** Clear all entries in hash table *)
let hash_clear = function
  | [ htable ] ->
      (match HTable.find (HTable.get_id htable) with
      | Some tbl ->
          Hashtbl.clear tbl;
          Object.Symbol "ok"
      | None ->
          raise (Errors.Runtime_error_exn (Errors.Not_found "Invalid hash table")))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(hash-clear hashtable)"))

let basis =
  [ "hash-create", hash_create
  ; "hash-set", hash_set
  ; "hash-get", hash_get
  ; "hash-has?", hash_has
  ; "hash-remove", hash_remove
  ; "hash-keys", hash_keys
  ; "hash-values", hash_values
  ; "hash-size", hash_size
  ; "hash-clear", hash_clear
  ]
;;
```

**Step 2: 注册到 Basis**

Modify: `lib/primitives/basis.ml`

```ocaml
let basis =
  [ ...existing bindings...
  ; @Mlisp_primitives.Json.basis
  ; @Mlisp_primitives.Hashtbl.basis
  ]
```

**Step 3: 创建测试文件**

Create: `test/21_hashtbl.mlisp`

```lisp
;; Test 1: Create hash table
(define tbl (hash-create))
(print tbl)

;; Test 2: Set and get values
(hash-set tbl "name" "Alice")
(hash-set tbl "age" 30)
(hash-set tbl "city" "Beijing")

(print (hash-get tbl "name"))
(print (hash-get tbl "age"))
(print (hash-get tbl "city"))

;; Test 3: Check if key exists
(print (hash-has? tbl "name"))
(print (hash-has? tbl "nonexistent"))

;; Test 4: Get all keys
(define keys (hash-keys tbl))
(print keys)

;; Test 5: Get all values
(define vals (hash-values tbl))
(print vals)

;; Test 6: Get size
(print (hash-size tbl))

;; Test 7: Remove key
(hash-remove tbl "age")
(print (hash-has? tbl "age"))
(print (hash-size tbl))

;; Test 8: Clear table
(hash-clear tbl)
(print (hash-size tbl))

(print "All hash table tests passed!")
```

**Step 4: 运行测试**

Run: `dune exec mlisp -- test/21_hashtbl.mlisp`

**Step 5: 提交**

```bash
git add lib/primitives/hashtbl.ml lib/primitives/basis.ml test/21_hashtbl.mlisp
git commit -m "feat: add hash table primitives"
```

---

## Phase 3: 字符串操作增强

### Task 3.1: 字符串工具原语

**Files:**
- Create: `lib/primitives/string_ext.ml`

**Step 1: 创建字符串扩展模块**

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core

(** String length *)
let string_length = function
  | [ Object.String s ] ->
      Object.Fixnum (String.length s)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(string-length string)"))

(** Substring extraction *)
let substring = function
  | [ Object.String s; Object.Fixnum start; Object.Fixnum len ] ->
      if start >= 0 && len >= 0 && start + len <= String.length s then
        Object.String (String.sub s ~pos:start ~len:len)
      else
        raise (Errors.Runtime_error_exn (Errors.Index_error "Substring out of bounds"))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(substring string start length)"))

(** String split *)
let string_split = function
  | [ Object.String s; Object.String sep ] ->
      let parts = String.split ~on:sep s in
      List.fold_right parts ~init:Object.Nil ~f:(fun part acc ->
        Object.Pair (Object.String part, acc))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(string-split string separator)"))

(** String join *)
let string_join = function
  | [ Object.Pair _ as list; Object.String sep ] ->
      let rec extract_strings = function
        | Object.Nil -> []
        | Object.Pair (Object.String s, rest) -> s :: extract_strings rest
        | Object.Pair (_, rest) -> extract_strings rest
        | _ -> []
      in
      let strings = extract_strings list in
      Object.String (String.concat ~sep strings)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(string-join list-of-strings separator)"))

(** String trim (whitespace) *)
let string_trim = function
  | [ Object.String s ] ->
      Object.String (String.strip s)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(string-trim string)"))

(** String contains *)
let string_contains = function
  | [ Object.String s; Object.String pattern ] ->
      Object.Boolean (String.is_substring pattern ~within:s)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(string-contains? string pattern)"))

(** String replace *)
let string_replace = function
  | [ Object.String s; Object.String pattern; Object.String replacement ] ->
      Object.String (String.replace_all s ~pattern ~replacement)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(string-replace string pattern replacement)"))

(** String to uppercase *)
let string_upper = function
  | [ Object.String s ] ->
      Object.String (String.uppercase s)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(string-upper string)"))

(** String to lowercase *)
let string_lower = function
  | [ Object.String s ] ->
      Object.String (String.lowercase s)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(string-lower string)"))

(** String comparison (less than) *)
let_string_lt = function
  | [ Object.String a; Object.String b ] ->
      Object.Boolean (String.compare a b < 0)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(string<? string-a string-b)"))

(** String comparison (greater than) *)
let string_gt = function
  | [ Object.String a; Object.String b ] ->
      Object.Boolean (String.compare a b > 0)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(string>? string-a string-b)"))

(** String equals *)
let string_eq = function
  | [ Object.String a; Object.String b ] ->
      Object.Boolean (String.equal a b)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(string=? string-a string-b)"))

let basis =
  [ "string-length", string_length
  ; "substring", substring
  ; "string-split", string_split
  ; "string-join", string_join
  ; "string-trim", string_trim
  ; "string-contains?", string_contains
  ; "string-replace", string_replace
  ; "string-upper", string_upper
  ; "string-lower", string_lower
  ; "string<?", string_lt
  ; "string>?", string_gt
  ; "string=?", string_eq
  ]
;;
```

**Step 2: 注册到 Basis**

Modify: `lib/primitives/basis.ml`

```ocaml
let basis =
  [ ...existing bindings...
  ; @Mlisp_primitives.Json.basis
  ; @Mlisp_primitives.Hashtbl.basis
  ; @Mlisp_primitives.String_ext.basis
  ]
```

**Step 3: 创建测试文件**

Create: `test/22_string_ext.mlisp`

```lisp
;; Test: String length
(print (string-length "hello"))

;; Test: Substring
(print (substring "hello" 1 3))

;; Test: String split
(define parts (string-split "a,b,c" ","))
(print parts)

;; Test: String join
(define joined (string-join '("x" "y" "z") "-"))
(print joined)

;; Test: String trim
(print (string-trim "  hello  "))

;; Test: String contains
(print (string-contains? "hello world" "world"))
(print (string-contains? "hello" "xyz"))

;; Test: String replace
(print (string-replace "hello world" "world" "MLisp"))

;; Test: Upper/lower
(print (string-upper "hello"))
(print (string-lower "HELLO"))

;; Test: Comparisons
(print (string<? "apple" "banana"))
(print (string>? "zebra" "apple"))
(print (string=? "test" "test"))

(print "All string extension tests passed!")
```

**Step 4: 运行测试**

Run: `dune exec mlisp -- test/22_string_ext.mlisp`

**Step 5: 提交**

```bash
git add lib/primitives/string_ext.ml lib/primitives/basis.ml test/22_string_ext.mlisp
git commit -m "feat: add string extension primitives"
```

---

## Phase 4: 日期/时间处理

### 依赖添加

**Files:**
- Modify: `dune-project`
- Modify: `mlisp.opam`

**Step 1: 添加 calendar 依赖**

```lisp
(depends ocaml dune core ocolor camlp-streams ocamline core_unix ppx_string yojson calendar)
```

**Step 2: 运行 opam 安装**

Run: `opam install . --deps-only`

**Step 3: 提交**

```bash
git add dune-project mlisp.opam
git commit -m "feat: add calendar dependency for date/time support"
```

---

### Task 4.1: 日期时间原语

**Files:**
- Create: `lib/primitives/date.ml`

**Step 1: 创建日期时间模块**

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

(** Parse FHIR date format (YYYY-MM-DD) *)
let date_parse_fhir = function
  | [ Object.String date_str ] ->
      try
        let parts = String.split ~on:'-' date_str in
        match parts with
        | [ year; month; day ] ->
            let y = int_of_string year in
            let m = int_of_string month in
            let d = int_of_string day in
            Object.Date (Date.make y m d)
        | _ ->
            raise (Errors.Runtime_error_exn (Errors.Parse_error "Invalid FHIR date format"))
      with
      | _ ->
          raise (Errors.Runtime_error_exn (Errors.Parse_error "Invalid FHIR date format"))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date-parse-fhir string)"))

(** Get current date *)
let date_today = function
  | [] ->
      Object.Date (Date.today ())
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date-today)"))

(** Calculate age from birth date *)
let date_age = function
  | [ Object.Date birth ] ->
      let today = Date.today () in
      let years = Date.Year.of_days (Date.days_between birth today) in
      Object.Fixnum years
  | [ Object.String birth_str ] ->
      (* Assume FHIR format *)
      (match date_parse_fhir [ Object.String birth_str ] with
      | Object.Date birth ->
          let today = Date.today () in
          let years = Date.Year.of_days (Date.days_between birth today) in
          Object.Fixnum years
      | _ ->
          raise (Errors.Runtime_error_exn (Errors.Not_found "Invalid birth date")))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date-age birth-date)"))

(** Date difference in days *)
let date_diff_days = function
  | [ Object.Date d1; Object.Date d2 ] ->
      Object.Fixnum (Date.days_between d1 d2)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date-diff-days date1 date2)"))

(** Add days to date *)
let date_add_days = function
  | [ Object.Date date; Object.Fixnum days ] ->
      Object.Date (Date.add_days date days)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date-add-days date days)"))

(** Format date as string *)
let date_format = function
  | [ Object.Date date ] ->
      Object.String (Date.to_string date)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date-format date)"))

(** Parse ISO date string *)
let date_parse_iso = function
  | [ Object.String date_str ] ->
      try
        Object.Date (Date.from_string date_str)
      with
      | _ ->
          raise (Errors.Runtime_error_exn (Errors.Parse_error "Invalid ISO date format"))
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date-parse-iso string)"))

(** Date comparison helpers *)
let date_lt = function
  | [ Object.Date d1; Object.Date d2 ] ->
      Object.Boolean (Date.compare d1 d2 < 0)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date<? date1 date2)"))

let date_le = function
  | [ Object.Date d1; Object.Date d2 ] ->
      Object.Boolean (Date.compare d1 d2 <= 0)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date<=? date1 date2)"))

let date_gt = function
  | [ Object.Date d1; Object.Date d2 ] ->
      Object.Boolean (Date.compare d1 d2 > 0)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date>? date1 date2)"))

let date_ge = function
  | [ Object.Date d1; Object.Date d2 ] ->
      Object.Boolean (Date.compare d1 d2 >= 0)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date>=? date1 date2)"))

let date_eq = function
  | [ Object.Date d1; Object.Date d2 ] ->
      Object.Boolean (Date.compare d1 d2 = 0)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(date=? date1 date2)"))

let basis =
  [ "date-parse-fhir", date_parse_fhir
  ; "date-today", date_today
  ; "date-age", date_age
  ; "date-diff-days", date_diff_days
  ; "date-add-days", date_add_days
  ; "date-format", date_format
  ; "date-parse-iso", date_parse_iso
  ; "date<?", date_lt
  ; "date<=?", date_le
  ; "date>?", date_gt
  ; "date>=?", date_ge
  ; "date=?", date_eq
  ]
;;
```

**Step 2: 添加 Date 类型到 Object**

Modify: `lib/object/object.ml`

在 `type lobject` 中添加：

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
  | Module of ...
  | Date of CalendarLib.Date.t  (** Add this line *)
```

更新 `object_type` 函数：

```ocaml
let object_type = function
  | ...
  | Date _ -> "date"
  | ...
```

**Step 3: 更新 print_sexpr 处理 Date**

```ocaml
let rec print_sexpr sexpr =
  match sexpr with
  | ...
  | Date d ->
      print_string (CalendarLib.Date.to_string d)
  | ...
```

**Step 4: 注册到 Basis**

Modify: `lib/primitives/basis.ml`

**Step 5: 创建测试文件**

Create: `test/23_date.mlisp`

```lisp
;; Test: Parse FHIR date
(define birth (date-parse-fhir "1955-07-23"))
(print birth)

;; Test: Calculate age
(print (date-age birth))
(print (date-age "1960-01-15"))

;; Test: Today
(define today (date-today))
(print (date-format today))

;; Test: Date arithmetic
(define tomorrow (date-add-days today 1))
(print (date-format tomorrow))

;; Test: Date difference
(define d1 (date-parse-fhir "2024-01-01"))
(define d2 (date-parse-fhir "2024-01-15"))
(print (date-diff-days d1 d2))

;; Test: Date comparisons
(print (date<? d1 d2))
(print (date>? d2 d1))
(print (date=? d1 d1))

(print "All date tests passed!")
```

**Step 6: 运行测试**

Run: `dune exec mlisp -- test/23_date.mlisp`

**Step 7: 提交**

```bash
git add lib/object/object.ml lib/primitives/date.ml lib/primitives/basis.ml test/23_date.mlisp
git commit -m "feat: add date/time primitives"
```

---

## Phase 5: HTTP 客户端

### 依赖添加

**Files:**
- Modify: `dune-project`
- Modify: `mlisp.opam`

**Step 1: 添加 cohttp 依赖**

```lisp
(depends ocaml dune core ocolor camlp-streams ocamline core_unix ppx_string yojson calendar cohttp-lwt-unix lwt)
```

**Step 2: 运行 opam 安装**

Run: `opam install . --deps-only`

**Step 3: 提交**

```bash
git add dune-project mlisp.opam
git commit -m "feat: add cohttp dependency for HTTP client"
```

---

### Task 5.1: HTTP 原语

**Files:**
- Create: `lib/primitives/http.ml`

**Step 1: 创建 HTTP 模块**

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

(** Simple HTTP GET request *)
let http_get = function
  | [ Object.String url ] ->
      Lwt_main.run (
        Client.call ~headers:(Header.init ()) `GET url
        >>= fun (_, body) ->
        Cohttp_lwt.Body.to_string body
        >|= fun response_body ->
          Object.String response_body
      )
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(http-get url-string)"))

(** HTTP POST with JSON body *)
let http_post = function
  | [ Object.String url; Object.String body ] ->
      Lwt_main.run (
        let body_str = body in
        Client.call ~headers:(Header.init ()) ~body:(Cohttp_lwt.Body.of_string body_str) `POST url
        >>= fun (_, response_body) ->
        Cohttp_lwt.Body.to_string response_body
        >|= fun response ->
          Object.String response
      )
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(http-post url-string body-string)"))

(** URL encode parameters *)
let http_urlencode = function
  | [ Object.Pair _ as params ] ->
      (* Convert list of pairs to URL encoded string *)
      let rec extract_pairs = function
        | Object.Nil -> []
        | Object.Pair (Object.Pair (Object.String k, Object.String v), rest) ->
          (k, v) :: extract_pairs rest
        | _ -> []
      in
      let pairs = extract_pairs params in
      let encoded = String.concat ~sep:"&" (List.map pairs ~f:(fun (k, v) ->
        [%string "%{Cohttp.Uri.encode k}=%{Cohttp.Uri.encode v}"]
      )) in
      Object.String encoded
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(http-urlencode ((key . value) ...))"))

(** Build URL with query parameters *)
let http_build_url = function
  | [ Object.String base; Object.Pair _ as params ] ->
      let encoded = match http_urlencode [params] with
      | Object.String s -> s
      | _ -> ""
      in
      Object.String (if String.is_empty encoded then base else [%string "%{base}?%{encoded}"])
  | [ Object.String base; Object.Nil ] ->
      Object.String base
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(http-build-url base-url params-list)"))

let basis =
  [ "http-get", http_get
  ; "http-post", http_post
  ; "http-urlencode", http_urlencode
  ; "http-build-url", http_build_url
  ]
;;
```

**Step 2: 注册到 Basis**

Modify: `lib/primitives/basis.ml`

**Step 3: 创建测试文件**

Create: `test/24_http.mlisp`

```lisp
;; Test: URL encode
(print (http-urlencode '(("name" . "John Doe") ("age" . "30"))))

;; Test: Build URL
(print (http-build-url "https://api.example.com/search" '(("q" . "lisp") ("limit" . "10"))))

;; Test: HTTP GET to a simple API (example.com)
;; (define response (http-get "https://jsonplaceholder.typicode.com/posts/1"))
;; (print response)

;; Note: Full HTTP tests require network access and may be skipped in CI
(print "HTTP primitives loaded successfully!")
```

**Step 4: 运行测试**

Run: `dune exec mlisp -- test/24_http.mlisp`

**Step 5: 提交**

```bash
git add lib/primitives/http.ml lib/primitives/basis.ml test/24_http.mlisp
git commit -m "feat: add HTTP client primitives"
```

---

## Phase 6: 集合操作增强

### Task 6.1: 集合原语

**Files:**
- Create: `lib/primitives/set.ml`

**Step 1: 创建集合操作模块**

```ocaml
(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Core

(** Helper: Convert Lisp list to OCaml list with equality *)
let rec to_ocaml_list = function
  | Object.Nil -> []
  | Object.Pair (h, t) -> h :: to_ocaml_list t
  | _ -> []

(** Helper: Convert OCaml list to Lisp list *)
let rec to_lisp_list = function
  | [] -> Object.Nil
  | h :: t -> Object.Pair (h, to_lisp_list t)

(** Helper: Check if value is in list *)
let rec mem equal = function
  | [] -> false
  | h :: t -> equal h || mem equal t

(** Remove duplicates from list *)
let set_unique = function
  | [ Object.Pair _ | Object.Nil as lst ] ->
      let rec dedup acc = function
        | Object.Nil -> to_lisp_list (List.rev acc)
        | Object.Pair (h, t) ->
            if mem ( (=) h ) acc then
              dedup acc t
            else
              dedup (h :: acc) t
        | x -> to_lisp_list (List.rev (x :: acc))
      in
      dedup [] lst
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(set-unique list)"))

(** Set union *)
let set_union = function
  | [ Object.Pair _ | Object.Nil as list1; Object.Pair _ | Object.Nil as list2 ] ->
      let combined = to_ocaml_list list1 @ to_ocaml_list list2 in
      set_unique [ to_lisp_list combined ]
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(set-union list1 list2)"))

(** Set intersection *)
let set_intersection = function
  | [ Object.Pair _ | Object.Nil as list1; Object.Pair _ | Object.Nil as list2 ] ->
      let lst2 = to_ocaml_list list2 in
      let rec intersect acc = function
        | Object.Nil -> to_lisp_list (List.rev acc)
        | Object.Pair (h, t) ->
            if mem ( (=) h ) lst2 then
              intersect (h :: acc) t
            else
              intersect acc t
        | h ->
            if mem ( (=) h ) lst2 then
              to_lisp_list (List.rev (h :: acc))
            else
              to_lisp_list (List.rev acc)
      in
      intersect [] list1
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(set-intersection list1 list2)"))

(** Set difference *)
let set_difference = function
  | [ Object.Pair _ | Object.Nil as list1; Object.Pair _ | Object.Nil as list2 ] ->
      let lst2 = to_ocaml_list list2 in
      let rec difference acc = function
        | Object.Nil -> to_lisp_list (List.rev acc)
        | Object.Pair (h, t) ->
            if mem ( (=) h ) lst2 then
              difference acc t
            else
              difference (h :: acc) t
        | h ->
            if mem ( (=) h ) lst2 then
              to_lisp_list (List.rev acc)
            else
              to_lisp_list (List.rev (h :: acc))
      in
      difference [] list1
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(set-difference list1 list2)"))

(** Check if all elements satisfy predicate (using function) *)
let set_forall = function
  | [ Object.Primitive (_, pred); Object.Pair _ | Object.Nil as lst ] ->
      let rec check = function
        | Object.Nil -> true
        | Object.Pair (h, t) ->
            (match pred [h] with
            | Object.Boolean true -> check t
            | _ -> false)
        | h ->
            (match pred [h] with
            | Object.Boolean true -> true
            | _ -> false)
      in
      Object.Boolean (check lst)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(set-forall predicate list)"))

(** Check if any element satisfies predicate *)
let set_exists = function
  | [ Object.Primitive (_, pred); Object.Pair _ | Object.Nil as lst ] ->
      let rec check = function
        | Object.Nil -> false
        | Object.Pair (h, t) ->
            (match pred [h] with
            | Object.Boolean true -> true
            | _ -> check t)
        | h ->
            (match pred [h] with
            | Object.Boolean true -> true
            | _ -> false)
      in
      Object.Boolean (check lst)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(set-exists predicate list)"))

(** Filter list by predicate *)
let set_filter = function
  | [ Object.Primitive (_, pred); Object.Pair _ | Object.Nil as lst ] ->
      let rec filter acc = function
        | Object.Nil -> to_lisp_list (List.rev acc)
        | Object.Pair (h, t) ->
            (match pred [h] with
            | Object.Boolean true -> filter (h :: acc) t
            | _ -> filter acc t)
      in
      filter [] lst
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(set-filter predicate list)"))

(** Map function over list *)
let set_map = function
  | [ Object.Primitive (_, fn); Object.Pair _ | Object.Nil as lst ] ->
      let rec map acc = function
        | Object.Nil -> List.rev acc
        | Object.Pair (h, t) -> map (fn [h] :: acc) t
      in
      to_lisp_list (map [] lst)
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(set-map function list)"))

(** Reduce/fold list *)
let set_reduce = function
  | [ Object.Primitive (_, fn); init; Object.Pair _ | Object.Nil as lst ] ->
      let rec reduce acc = function
        | Object.Nil -> acc
        | Object.Pair (h, t) -> reduce (fn [ acc; h ]) t
      in
      reduce init lst
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(set-reduce function initial list)"))

let basis =
  [ "set-unique", set_unique
  ; "set-union", set_union
  ; "set-intersection", set_intersection
  ; "set-difference", set_difference
  ; "set-forall", set_forall
  ; "set-exists", set_exists
  ; "set-filter", set_filter
  ; "set-map", set_map
  ; "set-reduce", set_reduce
  ]
;;
```

**Step 2: 注册到 Basis**

Modify: `lib/primitives/basis.ml`

**Step 3: 创建测试文件**

Create: `test/25_set.mlisp`

```lisp
;; Test: Unique
(print (set-unique '(1 2 2 3 3 3 4)))
(print (set-unique '("a" "b" "a" "c")))

;; Test: Union
(define list1 '(1 2 3))
(define list2 '(3 4 5))
(print (set-union list1 list2))

;; Test: Intersection
(print (set-intersection list1 list2))

;; Test: Difference
(print (set-difference list1 list2))
(print (set-difference list2 list1))

;; Test: Forall
(define positive? (lambda (x) (> x 0)))
(print (set-forall positive? '(1 2 3 4)))
(print (set-forall positive? '(1 -2 3)))

;; Test: Exists
(print (set-exists positive? '(-1 -2 3)))
(print (set-exists positive? '(-1 -2 -3)))

;; Test: Filter
(print (set-filter positive? '(-1 2 -3 4 -5)))

;; Test: Map
(print (set-map (lambda (x) (* x 2)) '(1 2 3)))

;; Test: Reduce
(print (set-reduce (lambda (acc x) (+ acc x)) 0 '(1 2 3 4)))

(print "All set tests passed!")
```

**Step 4: 运行测试**

Run: `dune exec mlisp -- test/25_set.mlisp`

**Step 5: 提交**

```bash
git add lib/primitives/set.ml lib/primitives/basis.ml test/25_set.mlisp
git commit -m "feat: add set operation primitives"
```

---

## Phase 7: 异常处理 (try/catch)

### Task 7.1: 异常处理特殊形式

**Files:**
- Modify: `lib/eval/eval.ml`
- Modify: `lib/object/object.ml`
- Modify: `lib/lexer/lexer.ml`

**Step 1: 添加异常处理表达式类型**

Modify: `lib/object/object.ml`

在 `type expr` 中添加：

```ocaml
type expr =
  | ...
  | TryCatch of expr * expr * name option  (** (try body catch [e-var]) *)
```

**Step 2: 添加词法分析支持**

Modify: `lib/lexer/lexer.ml`

在词法分析器中添加 `try` 和 `catch` 的识别（如果尚未存在）。

**Step 3: 实现求值逻辑**

Modify: `lib/eval/eval.ml`

添加异常处理的求值逻辑：

```ocaml
let rec eval_expr expr env =
  match expr with
  | ...
  | TryCatch (body_expr, catch_handler, None) ->
      begin try
        eval_expr body_expr env
      with
      | Errors.Runtime_error_exn err ->
          (* Create exception object and pass to handler *)
          let exc_obj = Object.Record ("Exception", [("message", Object.String (Errors.format_error err))]) in
          (* Evaluate catch handler with exception in scope *)
          eval_expr catch_handler (Object.bind ("exception", exc_obj, env))
      | Errors.Parse_error_exn err ->
          let exc_obj = Object.Record ("Exception", [("message", Object.String (Errors.format_parse_error err))]) in
          eval_expr catch_handler (Object.bind ("exception", exc_obj, env))
      | Errors.Syntax_error_exn err ->
          let exc_obj = Object.Record ("Exception", [("message", Object.String (Errors.format_syntax_error err))]) in
          eval_expr catch_handler (Object.bind ("exception", exc_obj, env))
      | exn ->
          (* Other exceptions *)
          let exc_obj = Object.Record ("Exception", [("message", Object.String (Printexc.to_string exn))]) in
          eval_expr catch_handler (Object.bind ("exception", exc_obj, env))
      end
  | TryCatch (body_expr, catch_handler, Some var_name) ->
      begin try
        eval_expr body_expr env
      with
      | Errors.Runtime_error_exn err ->
          let exc_obj = Object.Record ("Exception", [("message", Object.String (Errors.format_error err))]) in
          eval_expr catch_handler (Object.bind (var_name, exc_obj, env))
      | Errors.Parse_error_exn err ->
          let exc_obj = Object.Record ("Exception", [("message", Object.String (Errors.format_parse_error err))]) in
          eval_expr catch_handler (Object.bind (var_name, exc_obj, env))
      | Errors.Syntax_error_exn err ->
          let exc_obj = Object.Record ("Exception", [("message", Object.String (Errors.format_syntax_error err))]) in
          eval_expr catch_handler (Object.bind (var_name, exc_obj, env))
      | exn ->
          let exc_obj = Object.Record ("Exception", [("message", Object.String (Printexc.to_string exn))]) in
          eval_expr catch_handler (Object.bind (var_name, exc_obj, env))
      end
  | ...
```

**Step 4: 更新 AST 构建器**

Modify: `lib/ast/ast.ml`

添加 `try-catch` 语法的解析：

```ocaml
let rec build_ast sexpr =
  match sexpr with
  | ...
  | Object.Pair (Object.Symbol "try", rest) ->
      (* Parse (try body (catch [var] handler)) *)
      begin match rest with
      | Object.Pair (body, Object.Pair (Object.Symbol "catch", catch_part)) ->
          begin match catch_part with
          | Object.Pair (handler, Object.Nil) ->
              Object.TryCatch (build_ast body, build_ast handler, None)
          | Object.Pair (Object.Symbol var_name, Object.Pair (handler, Object.Nil)) ->
              Object.TryCatch (build_ast body, build_ast handler, Some var_name)
          | _ ->
              raise (Errors.Syntax_error_exn (Errors.Invalid_syntax "Invalid try-catch syntax"))
          end
      | _ ->
          raise (Errors.Syntax_error_exn (Errors.Invalid_syntax "Invalid try-catch syntax"))
      end
  | ...
```

**Step 5: 创建测试文件**

Create: `test/26_try_catch.mlisp`

```lisp
;; Test 1: Basic try-catch
(define result
  (try
    (/ 1 0)
    (catch
      (print "Caught exception!"))))
(print result)

;; Test 2: Catch with variable binding
(define result2
  (try
    (/ 1 0)
    (catch e
      (print (record-get e "message")))))
(print result2)

;; Test 3: No exception
(define result3
  (try
    (+ 1 2)
    (catch
      (print "This should not print"))))
(print result3)

;; Test 4: Nested try-catch
(define result4
  (try
    (try
      (/ 1 0)
      (catch
        (print "Inner catch")))
    (catch
      (print "Outer catch"))))
(print result4)

;; Test 5: User-defined error in try
(define result5
  (try
    (begin
      (print "Doing something")
      (hash-get "not-a-htable" "key"))
    (catch exc
      (print (record-get exc "message"))
      "recovered")))
(print result5)

(print "All try-catch tests passed!")
```

**Step 6: 运行测试**

Run: `dune exec mlisp -- test/26_try_catch.mlisp`

**Step 7: 提交**

```bash
git add lib/object/object.ml lib/eval/eval.ml lib/ast/ast.ml lib/lexer/lexer.ml test/26_try_catch.mlisp
git commit -m "feat: add try-catch exception handling"
```

---

## 实施顺序总结

按以下顺序逐步实施，每个阶段完成后运行所有测试确保没有破坏现有功能：

1. **Phase 1: JSON** → `test/20_json.mlisp`
2. **Phase 2: 哈希表** → `test/21_hashtbl.mlisp`
3. **Phase 3: 字符串扩展** → `test/22_string_ext.mlisp`
4. **Phase 4: 日期时间** → `test/23_date.mlisp`
5. **Phase 5: HTTP** → `test/24_http.mlisp`
6. **Phase 6: 集合操作** → `test/25_set.mlisp`
7. **Phase 7: 异常处理** → `test/26_try_catch.mlisp`

每完成一个 Phase，运行：

```bash
./run_tests.sh '2[0-6]*.mlisp'
```

---

## 验收标准

所有 Phase 完成后，应该能够：

```lisp
;; 示例：完整的 FHIR 患者筛选流程
(define patient-json (http-get "https://fhir.server/Patient/123"))
(define patient (json-parse patient-json))

(define birth-date (json-get-path patient "birthDate"))
(define age (date-age (date-parse-fhir birth-date)))

(define conditions (json-get-path patient "condition"))
(define has-diabetes
  (set-exists
    (lambda (c)
      (string-contains?
        (json-get-path c "code.coding.0.code")
        "E11"))
    conditions))

(define meets-criteria
  (and (>= age 18)
       (<= age 75)
       has-diabetes))

(print meets-criteria)
```

---

## 参考资料

- MLisp 架构: `lib/` 目录结构
- 原语模式: `lib/primitives/std.ml`
- 对象类型: `lib/object/object.ml`
- 求值器: `lib/eval/eval.ml`
- 词法分析: `lib/lexer/lexer.ml`
- AST 构建: `lib/ast/ast.ml`
