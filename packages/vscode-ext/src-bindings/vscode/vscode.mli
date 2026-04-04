(* VSCode API bindings for MLisp extension
   Generated using gen_js_api for type-safe interop *)

(* ExtensionContext *)
module ExtensionContext : sig
  type t = Ojs.t

  val subscriptions : t -> Ojs.t array
  val globalState : t -> Ojs.t
  val workspaceState : t -> Ojs.t
end

(* Disposable *)
module Disposable : sig
  type t = Ojs.t

  val from : t array -> t
  val dispose : t -> unit
end

(* Commands *)
module Commands : sig
  val registerCommand
    :  command:string
    -> callback:(Ojs.t array -> Ojs.t)
    -> Ojs.t

  val executeCommand
    :  command:string
    -> Ojs.t array
    -> Ojs.t
end

(* Window *)
module Window : sig
  val showInformationMessage
    :  message:string
    -> unit
    -> string option

  val createOutputChannel
    :  name:string
    -> Ojs.t
end

(* Workspace *)
module Workspace : sig
  val onDidChangeConfiguration
    :  listener:(Ojs.t -> Ojs.t)
    -> Ojs.t
end
