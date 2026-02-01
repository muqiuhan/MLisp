(* MLisp VSCode Extension *)

(* activate : ExtensionContext.t -> unit
 * Called by VSCode when the extension is activated *)
val activate : Ojs.t -> unit

(* deactivate : unit -> unit
 * Called by VSCode when the extension is deactivated *)
val deactivate : unit -> unit

(* start_repl : O.t array -> O.t
 * Opens the MLisp REPL webview panel *)
val start_repl : Ojs.t array -> Ojs.t

(* evaluate_selection : O.t array -> O.t
 * Evaluates the selected text in the active editor *)
val evaluate_selection : Ojs.t array -> Ojs.t
