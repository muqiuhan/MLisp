(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Core
open Types

let rec is_list = function
  | Nil ->
    true
  | Pair (_, b) ->
    is_list b
  | _ ->
    false
;;

let rec pair_to_list pair =
  match pair with
  | Nil ->
    []
  | Pair (a, b) ->
    a :: pair_to_list b
  | _ ->
    failwith "This can't happen!!!!"
;;

let rec list_to_pair = function
  | [] ->
    Nil
  | [ x ] ->
    Pair (x, Nil)
  | x :: xs ->
    Pair (x, list_to_pair xs)
;;

let rec append_lists list1 list2 =
  match list1 with
  | Nil ->
    list2
  | Pair (car, cdr) ->
    Pair (car, append_lists cdr list2)
  | _ ->
    Pair (list1, list2)
;;

let string_of_char a_char = String.make 1 a_char

let rec string_object e =
  let rec string_list l =
    match l with
    | Pair (a, Nil) ->
      string_object a
    | Pair (a, b) ->
      [%string "%{string_object a} %{string_list b}"]
    | _ ->
      failwith "This can't happen!!!!"
  in
  let string_pair p =
    match p with
    | Pair (a, b) ->
      [%string "%{string_object a} . %{string_object b}"]
    | _ ->
      failwith "This can't happen!!!!"
  in
    match e with
    | Fixnum v ->
      string_of_int v
    | Float f ->
      Float.to_string f
    | Boolean b ->
      if b then
        "#t"
      else
        "#f"
    | String s ->
      [%string {|"%{s}"|}]
    | Symbol s ->
      s
    | Nil ->
      "nil"
    | Pair _ ->
      [%string "(%{(if is_list e then string_list e else string_pair e)})\n"]
    | Primitive (name, _) ->
      [%string "#<primitive:%{name}>"]
    | Quote expr ->
      [%string "'%{string_object expr}"]
    | Quasiquote expr ->
      [%string "`%{string_object expr}"]
    | Unquote expr ->
      [%string ",%{string_object expr}"]
    | UnquoteSplicing expr ->
      [%string ",@%{string_object expr}"]
    | Closure (name, name_list, _, _) ->
      [%string {|#<%{name}:(%{String.concat ~sep:" " name_list})>|}]
    | Macro (name, param_specs, _, _) ->
      let params_str =
        let param_to_string = function
          | Fixed name ->
            name
          | Rest name ->
            "&rest " ^ name
        in
          String.concat ~sep:" " (List.map param_specs ~f:param_to_string)
      in
        [%string {|#<macro:%{name}:(%{params_str})>|}]
    | RestParam name ->
      "&rest " ^ name
    | Record (name, fields) ->
      let fields_string =
        let to_string (field_name, field_value) =
          [%string
            "%{field_name} = %{string_object field_value}"]
        in
          String.concat ~sep:"\n\t" (List.map ~f:to_string fields)
      in
        [%string "#<record:%{name}(\n\t%{fields_string}\n)>"]
    | Module { name; exports; _ } ->
      let exports_str = String.concat ~sep:" " exports in
        [%string "#<module:%{name}(exports: %{exports_str})>"]
;;
