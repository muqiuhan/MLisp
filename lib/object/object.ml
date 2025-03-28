(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_error
open Core

type lobject =
  | Fixnum of int
  | Boolean of bool
  | Symbol of string
  | String of string
  | Nil
  | Pair of lobject * lobject
  | Record of name * (name * lobject) list
  | Primitive of string * (lobject list -> lobject)
  | Quote of value
  | Closure of name * name list * expr * value env

and value = lobject
and name = string

and let_kind =
  | LET
  | LETSTAR
  | LETREC

and expr =
  | Literal of value
  | Var of name
  | If of expr * expr * expr
  | And of expr * expr
  | Or of expr * expr
  | Apply of expr * expr
  | Call of expr * expr list
  | Defexpr of def
  | Lambda of name * name list * expr
  | Let of let_kind * (name * expr) list * expr

and def =
  | Setq of name * expr
  | Defun of name * name list * expr
  | Expr of expr

and 'a env = (string * 'a option ref) list

type t = lobject

let rec is_list = function
  | Nil -> true
  | Pair (_, b) -> is_list b
  | _ -> false
;;

let object_type = function
  | Fixnum _ -> "int"
  | Boolean _ -> "boolean"
  | String _ -> "string"
  | Symbol _ -> "symbol"
  | Nil -> "nil"
  | Pair _ -> "pair"
  | Primitive _ -> "primitive"
  | Quote _ -> "quote"
  | Closure _ -> "closure"
  | Record _ -> "record"
;;

let rec print_sexpr sexpr =
  match sexpr with
  | Fixnum v -> print_string (Int.to_string v)
  | Boolean b ->
    print_string
      (if b then
         "#t"
       else
         "#f")
  | Symbol s -> print_string s
  | Nil -> print_string "nil"
  | Pair (_, _) ->
    print_string "(";
    if is_list sexpr then
      print_list sexpr
    else
      print_pair sexpr;
    print_string ")"
  | _ -> failwith "print_sexpr"

and print_list lst =
  match lst with
  | Pair (a, Nil) -> print_sexpr a
  | Pair (a, b) ->
    print_sexpr a;
    print_string " ";
    print_list b
  | _ -> failwith "This can't happen!!!!"

and print_pair pair =
  match pair with
  | Pair (a, b) ->
    print_sexpr a;
    print_string " . ";
    print_sexpr b
  | _ -> failwith "This can't happen!!!!"
;;

let rec pair_to_list pair =
  match pair with
  | Nil -> []
  | Pair (a, b) -> a :: pair_to_list b
  | _ -> failwith "This can't happen!!!!"
;;

let string_of_char a_char = String.make 1 a_char

let rec string_object e =
  let rec string_list l =
    match l with
    | Pair (a, Nil) -> string_object a
    | Pair (a, b) -> [%string "%{string_object a} %{string_list b}"]
    | _ -> failwith "This can't happen!!!!"
  in
  let string_pair p =
    match p with
    | Pair (a, b) -> [%string "%{string_object a} . %{string_object b}"]
    | _ -> failwith "This can't happen!!!!"
  in
    match e with
    | Fixnum v -> string_of_int v
    | Boolean b ->
      if b then
        "#t"
      else
        "#f"
    | String s -> [%string {|"%{s}"|}]
    | Symbol s -> s
    | Nil -> "nil"
    | Pair _ ->
      [%string "(%{(if is_list e then string_list e else string_pair e)})\n"]
    | Primitive (name, _) -> [%string "#<primitive:%{name}>"]
    | Quote expr -> [%string "%{string_object expr}"]
    | Closure (name, name_list, _, _) ->
      [%string {|#<%{name}:(%{String.concat ~sep:" " name_list})>|}]
    | Record (name, fields) ->
      let fields_string =
        let to_string (field_name, field_value) =
          [%string
            "%{field_name}: %{(object_type field_value)} = %{(string_object \
             field_value)}"]
        in
          [%string
            {|%{String.concat ~sep:"\n\t" (List.map ~f:to_string fields)}|}]
      in
        [%string "#<record:%{name}(\n\t%{fields_string}\n)>"]
;;

let rec lookup = function
  | n, [] -> raise (Errors.Runtime_error_exn (Errors.Not_found n))
  | n, (n', v) :: _ when String.(n = n') -> (
    match !v with
    | Some v' -> v'
    | None -> raise (Errors.Runtime_error_exn (Errors.Unspecified_value n)))
  | n, (_, _) :: bs -> lookup (n, bs)
;;

let bind (name, value, sexpr) = (name, ref (Some value)) :: sexpr
let make_local _ = ref None
let bind_local (n, vor, e) = (n, vor) :: e

let bind_list ns vs env =
  try Stdlib.List.fold_left2 (fun acc n v -> bind (n, v, acc)) env ns vs with
  | Invalid_argument _ ->
    raise (Errors.Runtime_error_exn (Errors.Missing_argument ns))
;;

let bind_local_list ns vs env =
  try
    Stdlib.List.fold_left2 (fun acc n v -> bind_local (n, v, acc)) env ns vs
  with
  | Invalid_argument _ ->
    raise (Errors.Runtime_error_exn (Errors.Missing_argument ns))
;;

let rec env_to_val =
  let b_to_val (n, vor) =
    Pair
      ( Symbol n
      , match !vor with
        | None -> Symbol "unspecified"
        | Some v -> v )
  in
    function
    | [] -> Nil
    | b :: bs -> Pair (b_to_val b, env_to_val bs)
;;
