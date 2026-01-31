(* VSCode API bindings for MLisp extension
   Generated using gen_js_api for type-safe interop *)

open Js_of_ocaml.Js

(* Core types *)
type extensionContext
type disposable
type command

(* ExtensionContext *)
module ExtensionContext : sig
  type t = extensionContext

  val subscriptions : t -> disposable array Ojs.t
  val globalState : t -> Ojs.t
  val workspaceState : t -> Ojs.t
end

(* Disposable *)
module Disposable : sig
  type t = disposable

  val from : t array -> t
  val make : dispose:(unit -> unit Ojs.t) -> t
  val dispose : t -> unit Ojs.t
end

(* Commands *)
module Commands : sig
  val registerCommand
    :  command:string
    -> callback:(Ojs.t array -> Ojs.t Ojs.t)
    -> unit Ojs.t
    -> command

  val executeCommand
    :  command:string
    -> Ojs.t array
    -> Ojs.t Ojs.t
end

(* Window *)
module Window : sig
  val showInformationMessage
    :  message:string
    -> unit Ojs.t
    -> string option Ojs.t

  val createOutputChannel
    :  name:string
    -> Ojs.t
end

(* Workspace *)
module Workspace : sig
  val onDidChangeConfiguration
    :  listener:(Ojs.t -> unit Ojs.t)
    -> unit Ojs.t
    -> disposable
end
