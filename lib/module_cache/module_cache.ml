(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Core

(* Open Core_unix for timestamp functions *)
module Time = Core_unix

(** {2 Module Cache State}

    This module provides a shared cache for modules that can be used by both
    the module loader (for file-based modules) and the evaluator (for inline
    modules defined in REPL or scripts). *)

(** Cache entry for a loaded module *)
type module_cache_entry =
  { module_object : Object.lobject  (** The module object *)
  ; module_env : Object.lobject Object.env  (** Module's internal environment *)
  ; source_path : string  (** Path to the source file, empty for inline modules *)
  ; timestamp : float  (** When the module was loaded *)
  }

(** Global module cache state *)
type cache_state =
  { cache : (string, module_cache_entry) Hashtbl.t  (** module_name -> cache_entry *)
  ; currently_loading : string list  (** Modules currently being loaded (for circular detection) *)
  }

let global_cache : cache_state ref =
  ref { cache = Hashtbl.create ~size:100 (module String)
      ; currently_loading = []
      }

(** {2 Cache Management Functions} *)

(** Clear all entries from the module cache *)
let clear_cache () =
  Hashtbl.clear !global_cache.cache

(** Get the number of cached modules *)
let get_cache_stats () =
  Hashtbl.length !global_cache.cache

(** Check if a module is in the cache *)
let is_cached module_name =
  Hashtbl.mem !global_cache.cache module_name

(** Get a cached module entry *)
let get_cached module_name =
  Hashtbl.find !global_cache.cache module_name

(** Get the global cache state (for use by module_loader) *)
let get_global_cache () =
  global_cache

(** Register a module in the cache.

    This function is called by eval.ml when an inline module is defined
    (e.g., in REPL or script). This ensures that inline modules are also
    tracked in the cache for module-cache-stats and module-cached?.

    @param module_name Name of the module
    @param module_obj The module object
    @param module_env The module's internal environment
    @param source_path Source path (empty string for inline modules) *)
let register_cached_module module_name (module_obj : Object.lobject)
    (module_env : Object.lobject Object.env) (source_path : string) : unit =
  let cache_entry =
    { module_object = module_obj
    ; module_env = module_env
    ; source_path
    ; timestamp = Time.gettimeofday ()
    }
  in
    Hashtbl.set !global_cache.cache ~key:module_name ~data:cache_entry
;;
