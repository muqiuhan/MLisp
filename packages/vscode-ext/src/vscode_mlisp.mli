(* MLisp VSCode Extension *)

(* activate : ExtensionContext.t -> unit
 * Called by VSCode when the extension is activated *)
val activate : Ojs.t -> unit

(* deactivate : unit -> unit
 * Called by VSCode when the extension is deactivated *)
val deactivate : unit -> unit
