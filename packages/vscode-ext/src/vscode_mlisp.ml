(* MLisp VSCode Extension - Main Entry Point
   Activates the extension and registers commands *)

module VscodeAPI = Vscode_bindings.Vscode
module O = Ojs
module Js = Js_of_ocaml.Js

(* Output channel for REPL *)
let output_channel : O.t option ref = ref None

(* Initialize output channel *)
let init_output () : unit =
  match !output_channel with
  | Some _ -> ()
  | None ->
      let channel = VscodeAPI.Window.createOutputChannel ~name:"MLisp REPL" in
      output_channel := Some channel;
      ignore (VscodeAPI.Window.showInformationMessage ~message:"MLisp extension activated!" ())

(* Start REPL command *)
let start_repl (_args : O.t array) : O.t =
  init_output ();
  match !output_channel with
  | None ->
      ignore (VscodeAPI.Window.showInformationMessage ~message:"REPL not available" ());
      O.unit_to_js ()
  | Some channel ->
      ignore (O.call channel "append" [| O.string_to_js "MLisp REPL Started\n" |]);
      ignore (O.call channel "show" [||]);
      O.unit_to_js ()

(* Evaluate selection command *)
let evaluate_selection (_args : O.t array) : O.t =
  init_output ();
  ignore (VscodeAPI.Window.showInformationMessage ~message:"Evaluation coming soon!" ());
  O.unit_to_js ()

(* Register all commands *)
let register_commands (_context : VscodeAPI.ExtensionContext.t) : VscodeAPI.Disposable.t =
  let start_repl_cmd =
    VscodeAPI.Commands.registerCommand ~command:"mlisp.startREPL"
      ~callback:start_repl
  in
  let evaluate_cmd =
    VscodeAPI.Commands.registerCommand ~command:"mlisp.evaluateSelection"
      ~callback:evaluate_selection
  in
  VscodeAPI.Disposable.from [| start_repl_cmd; evaluate_cmd |]

(* Extension activation *)
let activate (context : VscodeAPI.ExtensionContext.t) : unit =
  (* Register commands *)
  let _disposable = register_commands context in

  (* Subscribe to configuration changes *)
  let _config_disposable =
    VscodeAPI.Workspace.onDidChangeConfiguration
      ~listener:(fun (_event : O.t) -> O.unit_to_js ())
  in

  (* Show activation message *)
  init_output ();

  ()

(* Deactivate function *)
let deactivate () : unit =
  ()

(* Export activate function for VSCode *)
let () =
  Js.export "activate" (Js.wrap_callback activate)

(* Export deactivate function *)
let () =
  Js.export "deactivate" (Js.wrap_callback deactivate)
