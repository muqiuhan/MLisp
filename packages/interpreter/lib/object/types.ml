(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Core

(** The core Lisp object type representing all possible values in MLisp. *)
type lobject =
  | Fixnum of int                    (** Integer values *)
  | Float of float                   (** Floating point values *)
  | Boolean of bool                  (** Boolean values (#t or #f) *)
  | Symbol of string                 (** Symbol atoms used as identifiers *)
  | String of string                 (** String literals *)
  | Nil                              (** Empty list / nil value *)
  | Pair of lobject * lobject        (** Cons pairs forming lists *)
  | Record of name * (name * lobject) list (** Record structures *)
  | Primitive of string * (lobject list -> lobject) (** Built-in functions *)
  | Quote of value                   (** Quoted expressions *)
  | Quasiquote of value              (** Quasiquoted expressions (backtick) *)
  | Unquote of value                 (** Unquoted expressions (comma) *)
  | UnquoteSplicing of value         (** Unquote-splicing expressions (comma-at) *)
  | RestParam of string              (** Rest parameter marker (e.g., &rest) *)
  | Closure of name * name list * expr * closure_data (** Function closures *)
  | Macro of name * param_spec list * expr * lobject env
                                      (** Macro definitions with &rest support *)
  | Module of
      { name : string                (** Module name *)
      ; env : lobject env            (** Module's internal environment *)
      ; exports : string list        (** List of exported symbol names *)
      }                              (** Module objects *)

(** Closure data supporting both legacy and optimized environments.

    This variant allows backward compatibility while enabling performance
    optimizations for closure capture. *)
and closure_data =
  | Legacy of lobject env            (** Traditional full environment capture *)
  | Optimized of closure_env        (** Optimized selective variable capture *)

(** Optimized closure environment with selective variable capture.

    This structure captures only the free variables actually used by a closure,
    significantly reducing memory overhead and improving performance. *)
and closure_env =
  { captured_vars : (string * lobject option ref) list
                                    (** Variables captured from parent scopes *)
  ; parent_env : lobject env option (** Reference to parent environment for lookups *)
  }

and value = lobject
and name = string

and let_kind =
  | LET
  | LETSTAR
  | LETREC

and param_spec =
  | Fixed of string
  | Rest of string

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
  | ModuleDef of name * string list * expr list
                                      (** Module definition: name, exports, body *)
  | Import of import_spec            (** Module import *)
  | LoadModule of expr               (** Load module from file by name *)
  | MacroDef of name * param_spec list * expr
                                      (** Macro definition: (defmacro name (args) body) with &rest support *)

and def =
  | Setq of name * expr
  | Defun of name * name list * expr
  | Defmacro of name * param_spec list * expr (** Macro definition with &rest support *)
  | Expr of expr

(** Import specification for module imports. *)
and import_spec =
  | ImportAll of name                (** Import all exported symbols *)
  | ImportSelective of name * name list (** Import specific symbols *)
  | ImportAs of name * name          (** Import all with alias *)

(** Optimized environment structure with O(1) variable lookup.

    This hash-table based environment provides:
    - Constant-time variable lookup and binding
    - Lexical scoping through parent environment chaining
    - Efficient memory usage compared to list-based environments *)
and 'a env =
  { bindings : (string, 'a option ref) Hashtbl.t (** Variable bindings hash table *)
  ; parent : 'a env option        (** Parent environment for scoping *)
  ; level : int                   (** Environment nesting level *)
  }

type t = lobject

let object_type = function
  | Fixnum _ ->
    "int"
  | Float _ ->
    "float"
  | Boolean _ ->
    "boolean"
  | String _ ->
    "string"
  | Symbol _ ->
    "symbol"
  | Nil ->
    "nil"
  | Pair _ ->
    "pair"
  | Primitive _ ->
    "primitive"
  | Quote _ ->
    "quote"
  | Quasiquote _ ->
    "quasiquote"
  | Unquote _ ->
    "unquote"
  | UnquoteSplicing _ ->
    "unquote-splicing"
  | RestParam _ ->
    "rest-param"
  | Closure _ ->
    "closure"
  | Macro _ ->
    "macro"
  | Record _ ->
    "record"
  | Module _ ->
    "module"
;;
