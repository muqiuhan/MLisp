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
  | Closure of name * name list * expr * closure_data

and closure_data =
  | Legacy of lobject env (* old full environment *)
  | Optimized of closure_env (* new optimized environment *)

and closure_env =
  { captured_vars :
      (string * lobject option ref) list (* only capture needed variables *)
  ; parent_env : lobject env option (* reference parent environment *)
  }

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

and 'a env =
  { bindings : (string, 'a option ref) Hashtbl.t
  ; parent : 'a env option
  ; level : int
  }

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

let rec lookup (name, env) =
  match Hashtbl.find env.bindings name with
  | Some v -> (
    match !v with
    | Some v' -> v'
    | None ->
      (* for uninitialized variables, return a special unspecified value *)
      Symbol "unspecified")
  | None -> (
    match env.parent with
    | Some parent -> lookup (name, parent)
    | None -> raise (Errors.Runtime_error_exn (Errors.Not_found name)))
;;

(* create new empty environment *)
let create_env ?parent ?(level = 0) () =
  { bindings = Hashtbl.create (module String); parent; level }
;;

(* extend environment, create sub environment *)
let extend_env parent_env =
  create_env ~parent:parent_env ~level:(parent_env.level + 1) ()
;;

(* bind function *)
let bind (name, value, env) =
  Hashtbl.set env.bindings ~key:name ~data:(ref (Some value));
  env
;;

let make_local _ = ref None

let bind_local (name, value_ref, env) =
  Hashtbl.set env.bindings ~key:name ~data:value_ref;
  env
;;

let bind_list ns vs env =
  try
    List.iter2_exn ns vs ~f:(fun n v -> bind (n, v, env) |> ignore);
    env
  with
  | Invalid_argument _ ->
    raise (Errors.Runtime_error_exn (Errors.Missing_argument ns))
;;

let bind_local_list ns vs env =
  try
    List.iter2_exn ns vs ~f:(fun n v -> bind_local (n, v, env) |> ignore);
    env
  with
  | Invalid_argument _ ->
    raise (Errors.Runtime_error_exn (Errors.Missing_argument ns))
;;

let env_to_val env =
  let bindings = ref Nil in
    Hashtbl.iteri env.bindings ~f:(fun ~key:n ~data:vor ->
      let value =
        match !vor with
        | None -> Symbol "unspecified"
        | Some v -> v
      in
      let binding = Pair (Symbol n, value) in
        bindings := Pair (binding, !bindings));
    !bindings
;;

(* simplified free variable analysis *)
let analyze_free_vars expr bound_vars =
  let free_vars = ref [] in
  let rec collect_vars expr =
    match expr with
    | Var name ->
      if
        (not (List.mem bound_vars name ~equal:String.equal))
        && not (List.mem !free_vars name ~equal:String.equal)
      then
        free_vars := name :: !free_vars
    | If (cond, if_true, if_false) ->
      collect_vars cond;
      collect_vars if_true;
      collect_vars if_false
    | And (left, right) | Or (left, right) ->
      collect_vars left;
      collect_vars right
    | Apply (fn, args) ->
      collect_vars fn;
      collect_vars args
    | Call (fn, args) ->
      collect_vars fn;
      List.iter args ~f:collect_vars
    | Defexpr def -> begin
      match def with
      | Setq (_name, expr) -> collect_vars expr
      | Defun (_name, _params, body) ->
        collect_vars
          body (* note: here we don't add function name to bound_vars *)
      | Expr expr -> collect_vars expr
    end
    | Lambda (_name, _params, body) ->
      collect_vars body (* note: here we don't add parameters to bound_vars *)
    | Let (_kind, bindings, body) ->
      List.iter bindings ~f:(fun (_name, expr) -> collect_vars expr);
      collect_vars body
    | Literal _ -> ()
  in
    collect_vars expr;
    !free_vars
;;

(* create optimized closure environment *)
let create_closure_env free_vars env =
  let captured =
    List.filter_map free_vars ~f:(fun var_name ->
      match Hashtbl.find env.bindings var_name with
      | Some value_ref -> Some (var_name, value_ref)
      | None -> None)
  in
    { captured_vars = captured; parent_env = Some env }
;;

(* lookup variable in closure environment *)
let lookup_in_closure name closure_env =
  (* first lookup in captured variables *)
  let rec find_in_list = function
    | [] -> None
    | (n, value_ref) :: rest ->
      if String.equal n name then
        Some value_ref
      else
        find_in_list rest
  in
    match find_in_list closure_env.captured_vars with
    | Some value_ref -> begin
      match !value_ref with
      | Some v -> v
      | None -> raise (Errors.Runtime_error_exn (Errors.Unspecified_value name))
    end
    | None -> (
      (* if not in captured variables, lookup in parent environment *)
      match closure_env.parent_env with
      | Some parent -> lookup (name, parent)
      | None -> raise (Errors.Runtime_error_exn (Errors.Not_found name)))
;;
