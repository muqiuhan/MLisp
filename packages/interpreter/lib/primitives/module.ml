(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error

(** Placeholder for load-module primitive.

    Note: Full implementation requires environment context, which is not
    available in primitive functions. Module loading from files should be
    handled at a higher level or through a special form.

    @param args List containing a single string (module name)
    @raise Errors.Parse_error_exn always (not yet implemented) *)
let load_module_primitive = function
  | [ Object.String _module_name ] ->
    raise
      (Errors.Parse_error_exn
         (Errors.Type_error
            "(load-module \"module-name\") - not yet implemented. Use (module ...) to \
             define modules inline."))
  | _ ->
    raise (Errors.Parse_error_exn (Errors.Type_error "(load-module string)"))
;;

let basis = [ "load-module", load_module_primitive ]
