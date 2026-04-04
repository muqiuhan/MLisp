(* packages/interpreter/lib/object/environment.ml *)
open Mlisp_error
open Core
open Types

let parse_dotted_symbol (name : string) : (string * string) option =
  match String.rindex name '.' with
  | None ->
    None
  | Some dot_idx ->
    if dot_idx <= 0 || dot_idx >= String.length name - 1 then
      None
    else (
      let module_name = String.sub name ~pos:0 ~len:dot_idx in
      let symbol_len = String.length name - dot_idx - 1 in
      let symbol_name = String.sub name ~pos:(dot_idx + 1) ~len:symbol_len in
        Some (module_name, symbol_name)
    )
;;

type lobject = Types.lobject
type 'a env = 'a Types.env

let create_env ?parent ?(level = 0) () : lobject env =
  { bindings = Hashtbl.create (module String); parent; level }
;;

let extend_env (parent_env : lobject env) : lobject env =
  create_env ~parent:parent_env ~level:(parent_env.level + 1) ()
;;

let bind (name, value, env : string * lobject * (lobject env)) =
  Hashtbl.set env.bindings ~key:name ~data:(ref (Some value));
  env
;;

let make_local _ = ref None

let bind_local (name, value_ref, env : string * lobject option ref * (lobject env)) =
  Hashtbl.set env.bindings ~key:name ~data:value_ref;
  env
;;

let bind_list ns vs env =
  try
    List.iter2_exn ns vs ~f:(fun n v -> bind (n, v, env) |> ignore);
    Ok env
  with
  | Invalid_argument _ ->
    Error (Errors.Not_found ("Missing_argument: " ^ String.concat ~sep:" " ns))
;;

let bind_local_list ns vs env =
  try
    List.iter2_exn ns vs ~f:(fun n v -> bind_local (n, v, env) |> ignore);
    Ok env
  with
  | Invalid_argument _ ->
    Error (Errors.Not_found ("Missing_argument: " ^ String.concat ~sep:" " ns))
;;

let rec lookup (name, env : string * (lobject env)) : (lobject, Errors.runtime_error) Result.t =
  match Hashtbl.find env.bindings name with
  | Some v -> (
    match !v with
    | Some v' ->
      Ok v'
    | None ->
      Ok (Symbol "unspecified"))
  | None -> (
    match parse_dotted_symbol name with
    | Some (module_name, symbol_name) ->
      lookup_dotted name module_name symbol_name env
    | None -> (
      match env.parent with
      | Some parent ->
        lookup (name, parent)
      | None ->
        Error (Errors.Not_found name)))

and lookup_dotted full_name module_name symbol_name (env : lobject env) =
  let rec lookup_mod (env : lobject env) =
    match Hashtbl.find env.bindings module_name with
    | Some v -> (
      match !v with
      | Some module_obj ->
        Ok module_obj
      | None ->
        Ok (Symbol "unspecified"))
    | None -> (
      match env.parent with
      | Some parent ->
        lookup_mod parent
      | None ->
        Error (Errors.Not_found module_name))
  in
  match lookup_mod env with
  | Ok (Module { env = module_env; _ }) ->
    lookup (symbol_name, module_env)
  | Ok _ ->
    Error (Errors.Not_found full_name)
  | Error _ ->
    Error (Errors.Not_found full_name)
;;

let env_to_val (env : lobject env) =
  let bindings = ref Nil in
    Hashtbl.iteri env.bindings ~f:(fun ~key:n ~data:vor ->
      let value =
        match !vor with
        | None ->
          Symbol "unspecified"
        | Some v ->
          v
      in
      let binding = Pair (Symbol n, value) in
        bindings := Pair (binding, !bindings));
    !bindings
;;