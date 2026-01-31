(* VSCode API bindings implementation *)
[@@@js.default
  [|{| vsCode |}|]]
[@@js]

let vscode = Ojs.variable "vscode"

module ExtensionContext = struct
  type t = Ojs.t

  let subscriptions (ctx : t) =
    Ojs.(get (ctx |> Ojs.variable "ctx") "subscriptions")
    |> Ojs.to_array

  let globalState (ctx : t) =
    Ojs.(get ctx "globalState")

  let workspaceState (ctx : t) =
    Ojs.(get ctx "workspaceState")
end

module Disposable = struct
  type t = Ojs.t

  let from (disposables : t array) =
    Ojs.(let arr = Array.map (fun x -> x) disposables in
      Ojs.call (Ojs.method vscode "Disposable.from") arr [| arr |])

  let make ~dispose =
    let dispose_fn = Js.wrap_callback dispose in
    Ojs.call (Ojs.method vscode "Disposable.from") ()
      [| Js.Unsafe.any_func dispose_fn |]

  let dispose (d : t) =
    Ojs.call (Ojs.get d "dispose") d [||]
end

module Commands = struct
  let registerCommand ~command ~callback =
    let callback_fn = Js.wrap_callback
      (fun args ->
        let js_args = Js.to_array args in
        callback js_args)
    in
    Ojs.call (Ojs.method vscode "commands.registerCommand") vscode
      [| Js.string command; Js.Unsafe.any_func callback_fn |]

  let executeCommand ~command args =
    Ojs.call (Ojs.method vscode "commands.executeCommand") vscode
      (Array.map (fun x -> x) (@@ [ Js.string command ]) |> Array.append args)
end

module Window = struct
  let showInformationMessage ~message () =
    let result =
      Ojs.call (Ojs.method vscode "window.showInformationMessage") vscode
        [| Js.string message |]
    in
    match Ojs.opt_result result with
    | Some s -> Some (Js.to_string s)
    | None -> None

  let createOutputChannel ~name =
    Ojs.call (Ojs.method vscode "window.createOutputChannel") vscode
      [| Js.string name |]
end

module Workspace = struct
  let onDidChangeConfiguration ~listener =
    let listener_fn = Js.wrap_callback listener in
    Ojs.call (Ojs.method vscode "workspace.onDidChangeConfiguration") vscode
      [| Js.Unsafe.any_func listener_fn |]
end
