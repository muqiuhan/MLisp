(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object

(** Initialize the base environment with primitive functions and core bindings.

    Creates the foundation environment that contains all built-in MLisp
    functions and essential symbols. This environment serves as the root for all
    MLisp program execution and provides access to core language primitives.

    The initialization process: 1. Creates a fresh hash-table based environment
    2. Binds the empty symbol for string operations 3. Loads all primitive
    function collections (numeric, string, standard) 4. Returns the fully
    populated base environment

    This module is critical for bootstrapping the MLisp interpreter and
    establishing the core language functionality. *)

(** The base environment containing all MLisp primitive functions and symbols.

    This environment includes:
    - Arithmetic operations (Num.basis)
    - String manipulation functions (String.basis)
    - Core Lisp operations (Std.basis)
    - Essential symbols like "empty-symbol"

    All MLisp programs start with this environment as their foundation. *)
let basis =
  let newprim acc (name, func) = Object.bind (name, Object.Primitive (name, func), acc) in
  let initial_env = Object.create_env () in
    Object.bind ("empty-symbol", Object.Symbol "", initial_env) |> ignore;
    Object.bind ("nil", Object.Nil, initial_env) |> ignore;
    [ Num.basis; String.basis; Std.basis ]
    |> Core.List.concat
    |> Core.List.fold_left ~f:newprim ~init:initial_env
;;
