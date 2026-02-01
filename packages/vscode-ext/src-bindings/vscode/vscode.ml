(* VSCode API bindings implementation *)

let vscode = Ojs.variable "vscode"

module ExtensionContext = struct
  type t = Ojs.t

  let subscriptions (ctx : t) =
    Ojs.get_prop_ascii ctx "subscriptions"
    |> Ojs.array_of_js Ojs.t_of_js

  let globalState (ctx : t) =
    Ojs.get_prop_ascii ctx "globalState"

  let workspaceState (ctx : t) =
    Ojs.get_prop_ascii ctx "workspaceState"
end

module Disposable = struct
  type t = Ojs.t

  let from (disposables : t array) =
    let arr = Array.map (fun x -> x) disposables in
    let disposable = Ojs.get_prop_ascii vscode "Disposable" in
    Ojs.call disposable "from" [| Ojs.array_to_js Ojs.t_of_js arr |]

  let dispose (d : t) =
    ignore (Ojs.call d "dispose" [||])
end

module Commands = struct
  let registerCommand ~command ~callback =
    let callback_fn =
      Ojs.fun_to_js_args (fun args ->
        let js_args = Ojs.array_of_js Ojs.t_of_js args in
        callback js_args)
    in
    let commands = Ojs.get_prop_ascii vscode "commands" in
    Ojs.call commands "registerCommand" [| Ojs.string_to_js command; callback_fn |]

  let executeCommand ~command args =
    let commands = Ojs.get_prop_ascii vscode "commands" in
    Ojs.call commands "executeCommand"
      (Array.append [| Ojs.string_to_js command |] args)
end

module Window = struct
  let showInformationMessage ~message () =
    let window = Ojs.get_prop_ascii vscode "window" in
    let result = Ojs.call window "showInformationMessage" [| Ojs.string_to_js message |] in
    Ojs.option_of_js Ojs.string_of_js result

  let createOutputChannel ~name =
    let window = Ojs.get_prop_ascii vscode "window" in
    Ojs.call window "createOutputChannel" [| Ojs.string_to_js name |]
end

module Workspace = struct
  let onDidChangeConfiguration ~listener =
    let listener_fn = Ojs.fun_to_js_args listener in
    let workspace = Ojs.get_prop_ascii vscode "workspace" in
    Ojs.call workspace "onDidChangeConfiguration" [| listener_fn |]
end
