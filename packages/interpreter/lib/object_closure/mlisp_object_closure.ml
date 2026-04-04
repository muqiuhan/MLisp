(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Core
include Mlisp_object.Object

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
    | And (left, right)
    | Or (left, right) ->
      collect_vars left;
      collect_vars right
    | Apply (fn, args) ->
      collect_vars fn;
      collect_vars args
    | Call (fn, args) ->
      collect_vars fn;
      List.iter args ~f:collect_vars
    | Defexpr def -> (
      match def with
      | Setq (_name, expr) ->
        collect_vars expr
      | Defun (_name, _params, body) ->
        collect_vars body
      | Defmacro (_name, _params, body) ->
        collect_vars body
      | Expr expr ->
        collect_vars expr)
    | Lambda (_name, _params, body) ->
      collect_vars body
    | Let (_kind, bindings, body) ->
      List.iter bindings ~f:(fun (_name, expr) -> collect_vars expr);
      collect_vars body
    | ModuleDef (_name, _exports, body_exprs) ->
      List.iter body_exprs ~f:collect_vars
    | Import _ ->
      ()
    | LoadModule _ ->
      ()
    | MacroDef (_name, _params, body) ->
      collect_vars body
    | Literal _ ->
      ()
  in
    collect_vars expr;
    !free_vars
;;

let create_closure_env free_vars env =
  let captured =
    List.filter_map free_vars ~f:(fun var_name ->
      match Hashtbl.find env.bindings var_name with
      | Some value_ref ->
        Some (var_name, value_ref)
      | None ->
        None)
  in
    { captured_vars = captured; parent_env = Some env }
;;

let lookup_in_closure name closure_env =
  let rec find_in_list = function
    | [] ->
      None
    | (n, value_ref) :: rest ->
      if String.equal n name then
        Some value_ref
      else
        find_in_list rest
  in
    match find_in_list closure_env.captured_vars with
    | Some value_ref -> (
      match !value_ref with
      | Some v ->
        v
      | None ->
        raise (Mlisp_error.Errors.Runtime_error_exn (Mlisp_error.Errors.Unspecified_value name)))
    | None -> (
      match closure_env.parent_env with
      | Some parent ->
        lookup (name, parent)
      | None ->
        raise (Mlisp_error.Errors.Runtime_error_exn (Mlisp_error.Errors.Not_found name)))
;;
