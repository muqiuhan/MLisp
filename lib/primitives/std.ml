(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error
open Module_cache

let rec list = function
  | [] ->
    Object.Nil
  | car :: cdr ->
    Object.Pair (car, list cdr)
;;

let pair = function
  | [ a; b ] ->
    Object.Pair (a, b)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(pair a b)"))
;;

let car = function
  | [ Object.Pair (car, _) ] ->
    car
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(car non-nil-pair)"))
;;

let cdr = function
  | [ Object.Pair (_, cdr) ] ->
    cdr
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(cdr non-nil-pair)"))
;;

let atomp = function
  | [ Object.Pair (_, _) ] ->
    Object.Boolean false
  | [ _ ] ->
    Object.Boolean true
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(atom? something)"))
;;

let eq = function
  | [ a; b ] ->
    Object.Boolean (a = b)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(eq a b)"))
;;

let symp = function
  | [ Object.Symbol _ ] ->
    Object.Boolean true
  | [ _ ] ->
    Object.Boolean false
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(sym? single-arg)"))
;;

let getchar = function
  | [] -> (
    try Object.Fixnum (int_of_char @@ input_char stdin) with
    | End_of_file ->
      Object.Fixnum (-1))
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(getchar)"))
;;

let print = function
  | [ v ] ->
    let () = print_string @@ Object.string_object v in
      Object.Symbol "ok"
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(print object)"))
;;

let int_to_char = function
  | [ Object.Fixnum i ] ->
    Object.Symbol (Object.string_of_char @@ char_of_int i)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(int_to_char int)"))
;;

let cat = function
  | [ Object.Symbol a; Object.Symbol b ] ->
    Object.Symbol [%string "%{a}%{b}"]
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(cat sym sym)"))
;;

let record_get = function
  | [ Object.Record (_, fields); Object.Symbol get ] ->
    List.assoc get fields
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(record field-name)"))
;;

let record_create = function
  | [ Object.Symbol record_name; fields ] ->
    let rec record_fields fields record =
      match fields with
      | Object.Pair (field_name, field_value) -> (
        match field_name, field_value with
        | (Object.Pair _ as field_1), (Object.Pair _ as field_2) ->
          record_fields field_1 record @ record_fields field_2 record
        | Object.Pair (Object.Symbol field_name, field_value), Nil
        | Object.Symbol field_name, field_value ->
          (field_name, field_value) :: record
        | _ ->
          raise
            (Errors.Syntax_error_exn
               (Errors.Record_field_name_must_be_a_symbol record_name)))
      | _ ->
        failwith "record fields must be a list of pairs"
    in
      Object.Record (record_name, record_fields fields [])
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(record field-name)"))
;;

let floatp = function
  | [ Object.Float _ ] ->
    Object.Boolean true
  | [ _ ] ->
    Object.Boolean false
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(float? single-arg)"))
;;

let intp = function
  | [ Object.Fixnum _ ] ->
    Object.Boolean true
  | [ _ ] ->
    Object.Boolean false
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(int? single-arg)"))
;;

let int_to_float = function
  | [ Object.Fixnum i ] ->
    Object.Float (float_of_int i)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(int->float int)"))
;;

let float_to_int = function
  | [ Object.Float f ] ->
    Object.Fixnum (int_of_float f)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(float->int float)"))
;;

let floor_fn = function
  | [ Object.Float f ] ->
    let i = int_of_float f in
      if f >= 0.0 || f = float_of_int i then
        Object.Float (float_of_int i)
      else
        Object.Float (float_of_int (i - 1))
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(floor float)"))
;;

let ceil_fn = function
  | [ Object.Float f ] ->
    let i = int_of_float f in
      if f <= 0.0 || f = float_of_int i then
        Object.Float (float_of_int i)
      else
        Object.Float (float_of_int (i + 1))
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(ceil float)"))
;;

let round_fn = function
  | [ Object.Float f ] ->
    Object.Float (Float.round f)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(round float)"))
;;

let sqrt_fn = function
  | [ Object.Float f ] ->
    Object.Float (Float.sqrt f)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(sqrt float)"))
;;

let pow_fn = function
  | [ Object.Float a; Object.Float b ] ->
    Object.Float (Float.pow a b)
  | [ Object.Fixnum a; Object.Float b ] ->
    Object.Float (Float.pow (float_of_int a) b)
  | [ Object.Float a; Object.Fixnum b ] ->
    Object.Float (Float.pow a (float_of_int b))
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(pow float float)"))
;;

let abs_fn = function
  | [ Object.Float f ] ->
    Object.Float (Float.abs f)
  | [ Object.Fixnum i ] ->
    Object.Fixnum (abs i)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(abs number)"))
;;

let exp_fn = function
  | [ Object.Float f ] ->
    Object.Float (Float.exp f)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(exp float)"))
;;

let log_fn = function
  | [ Object.Float f ] ->
    Object.Float (Float.log f)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(log float)"))
;;

let sin_fn = function
  | [ Object.Float f ] ->
    Object.Float (Float.sin f)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(sin float)"))
;;

let cos_fn = function
  | [ Object.Float f ] ->
    Object.Float (Float.cos f)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(cos float)"))
;;

let tan_fn = function
  | [ Object.Float f ] ->
    Object.Float (Float.tan f)
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(tan float)"))
;;

(** Gensym counter for generating unique symbols *)
let gensym_counter = ref 0

(** Generate a unique symbol for hygienic macro expansion.
    Optionally accepts a prefix symbol or string.

    (gensym) -> g1, g2, g3, ...
    (gensym 'temp) -> temp_1, temp_2, ...
    (gensym "temp") -> temp_1, temp_2, ...
*)
let gensym = function
  | [] ->
    incr gensym_counter;
    Object.Symbol [%string "g%{Int.to_string !gensym_counter}"]
  | [ Object.Symbol prefix ] ->
    incr gensym_counter;
    Object.Symbol [%string "%{prefix}_%{Int.to_string !gensym_counter}"]
  | [ Object.String prefix ] ->
    incr gensym_counter;
    Object.Symbol [%string "%{prefix}_%{Int.to_string !gensym_counter}"]
  | [ _arg ] ->
    raise
      (Errors.Parse_error_exn
         (Errors.Type_error "(gensym [optional-prefix-symbol-or-string])"))
  | _ ->
    raise
      (Errors.Parse_error_exn
         (Errors.Type_error "(gensym [optional-prefix-symbol-or-string])"))
;;
;;

(** Module cache management primitives *)

let module_clear_cache = function
  | [] ->
      clear_cache ();
      Object.Symbol "ok"
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(module-clear-cache)"))
;;

let module_cache_stats = function
  | [] ->
      Object.Fixnum (get_cache_stats ())
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(module-cache-stats)"))
;;

let module_is_cached = function
  | [ Object.Symbol module_name ] ->
      let cached = is_cached module_name in
      Object.Boolean cached
  | _ ->
      raise (Errors.Parse_error_exn (Errors.Type_error "(module-cached? module-name)"))
;;

let basis =
  [ "list", list
  ; "cons", pair
  ; "car", car
  ; "cdr", cdr
  ; "==", eq
  ; "atom?", atomp
  ; "symbol?", symp
  ; "gensym", gensym (* Hygienic macro support *)
  ; "module-clear-cache", module_clear_cache (* Module cache management *)
  ; "module-cache-stats", module_cache_stats
  ; "module-cached?", module_is_cached
  ; "getchar", getchar
  ; "print", print
  ; "int->char", int_to_char
  ; "symbol-concat", cat
  ; "record-get", record_get
  ; "record", record_create (* Type predicates *)
  ; "float?", floatp
  ; "int?", intp (* Type conversions *)
  ; "int->float", int_to_float
  ; "float->int", float_to_int (* Math functions *)
  ; "floor", floor_fn
  ; "ceil", ceil_fn
  ; "round", round_fn
  ; "sqrt", sqrt_fn
  ; "pow", pow_fn
  ; "abs", abs_fn
  ; "exp", exp_fn
  ; "log", log_fn
  ; "sin", sin_fn
  ; "cos", cos_fn
  ; "tan", tan_fn
  ]
;;
