(* MLisp VSCode Extension - Main Entry Point
   Activates the extension and registers commands *)

open Vscode_bindings

(* Output channel for REPL *)
let output_channel = ref None

(* Initialize output channel *)
let init_output () =
  match !output_channel with
  | Some _ -> ()
  | None ->
      let channel = Window.createOutputChannel ~name:"MLisp REPL" in
      output_channel := Some channel;
      Window.showInformationMessage ~message:"MLisp extension activated!" ()

(* Start REPL command *)
let start_repl () =
  init_output ();
  match !output_channel with
  | None -> Window.showInformationMessage ~message:"REPL not available" ()
  | Some channel ->
      Ojs.call (Ojs.method channel "append") channel [| Js.string "MLisp REPL Started\n" |];
      Ojs.call (Ojs.method channel "show") channel [||];
      Js.undefined

(* Evaluate selection command *)
let evaluate_selection () =
  init_output ();
  (* TODO: Get editor selection and evaluate *)
  Window.showInformationMessage ~message:"Evaluation coming soon!" ()

(* Register all commands *)
let register_commands (context : ExtensionContext.t) =
  let start_repl_cmd =
    Commands.registerCommand ~command:"mlisp.startREPL"
      ~callback:(fun _args -> start_repl ()) ()
  in
  let evaluate_cmd =
    Commands.registerCommand ~command:"mlisp.evaluateSelection"
      ~callback:(fun _args -> evaluate_selection ()) ()
  in
  Disposable.from [| start_repl_cmd; evaluate_cmd |]

(* Extension activation *)
let activate (context : ExtensionContext.t) =
  (* Register commands *)
  let disposable = register_commands context in
  ExtensionContext.subscriptions context |> Array.iter Disposable.dispose;

  (* Subscribe to configuration changes *)
  ignore (Workspace.onDidChangeConfiguration
    ~listener:(fun _event -> Js.undefined)
    ());

  (* Show activation message *)
  init_output ();

  Js.undefined

(* Export activate function for VSCode *)
let () =
  let open Js_of_ocaml.Js in
  export "activate" (wrap_callback activate)

(* Export deactivate function *)
let () =
  let open Js_of_ocaml.Js in
  export "deactivate" (wrap_callback (fun () -> Js.undefined))
