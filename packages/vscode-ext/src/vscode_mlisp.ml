(* MLisp VSCode Extension - Main Entry Point
   Activates the extension and registers commands *)

module VscodeAPI = Vscode_bindings.Vscode
module O = Ojs
module Js = Js_of_ocaml.Js

(* REPL panel reference *)
let repl_panel : O.t option ref = ref None

(* VSCode global object *)
let vscode = Ojs.variable "vscode"

(* Node.js modules *)
let require (name : string) : O.t =
  Ojs.apply (Ojs.variable "require") [| Ojs.string_to_js name |]

(* Node.js child_process and path modules *)
let child_process = ref None
let path_module = ref None
let fs_module = ref None

(* Initialize Node.js modules lazily *)
let init_node_modules () : unit =
  if !child_process = None then (
    child_process := Some (require "child_process");
    path_module := Some (require "path");
    fs_module := Some (require "fs")
  )

(* Find the MLisp executable path *)
let find_mlisp_executable () : string =
  init_node_modules ();
  let fs = Option.get !fs_module in
  let process_obj = Ojs.variable "process" in

  (* Get extension path from context *)
  let cwd = Ojs.apply (Ojs.get_prop_ascii process_obj "cwd") [||] in
  let cwd_str = Ojs.string_of_js cwd in

  (* Try to find mlisp in the build directory *)
  let candidates = [
    Filename.concat (Filename.concat cwd_str "packages") "interpreter";
    Filename.concat cwd_str "../interpreter";
  ] in

  let rec check_path = function
    | [] -> "mlisp" (* Fallback to system PATH *)
    | base_path :: rest ->
        let exe_path = Filename.concat (Filename.concat base_path "_build/default/bin/") "mlisp.exe" in
        let exists = Ojs.bool_of_js (Ojs.call fs "existsSync" [| Ojs.string_to_js exe_path |]) in
        if exists then exe_path
        else (
          let bc_path = Filename.concat (Filename.concat base_path "_build/default/bin/") "mlisp.bc" in
          let exists = Ojs.bool_of_js (Ojs.call fs "existsSync" [| Ojs.string_to_js bc_path |]) in
          if exists then bc_path
          else check_path rest
        )
  in
    check_path candidates

(* MLisp process reference *)
let mlisp_process : O.t option ref = ref None
let mlisp_output_buffer : string ref = ref ""
let mlisp_is_ready = ref false

(* Handle MLisp process output *)
let handle_mlisp_output =
  Ojs.fun_to_js_args (fun data ->
    let text = Ojs.string_of_js data in
    mlisp_output_buffer := !mlisp_output_buffer ^ text;
    Ojs.unit_to_js ())

(* Handle MLisp process errors *)
let handle_mlisp_error =
  Ojs.fun_to_js_args (fun data ->
    let text = Ojs.string_of_js data in
    mlisp_output_buffer := !mlisp_output_buffer ^ "[error] " ^ text;
    Ojs.unit_to_js ())

(* Handle MLisp process close *)
let handle_mlisp_close =
  Ojs.fun_to_js_args (fun _code ->
    mlisp_process := None;
    mlisp_is_ready := false;
    Ojs.unit_to_js ())

(* Initialize MLisp process *)
let init_mlisp_process () : unit =
  init_node_modules ();
  if !mlisp_process = None then (
    let executable = find_mlisp_executable () in
    let spawn = Ojs.get_prop_ascii (Option.get !child_process) "spawn" in
    let proc = Ojs.apply spawn [| Ojs.string_to_js executable |] in

    (* Set up handlers *)
    let stdout = Ojs.get_prop_ascii proc "stdout" in
    let stderr = Ojs.get_prop_ascii proc "stderr" in

    ignore (Ojs.call stdout "on" [| Ojs.string_to_js "data"; handle_mlisp_output |]);
    ignore (Ojs.call stderr "on" [| Ojs.string_to_js "data"; handle_mlisp_error |]);
    ignore (Ojs.call proc "on" [| Ojs.string_to_js "close"; handle_mlisp_close |]);

    mlisp_process := Some proc;
    mlisp_is_ready := true
  )

(* Send input to MLisp process *)
let send_to_mlisp (input : string) : unit =
  init_mlisp_process ();
  match !mlisp_process with
  | None -> ()
  | Some proc ->
      let stdin = Ojs.get_prop_ascii proc "stdin" in
      ignore (Ojs.call stdin "write" [| Ojs.string_to_js (input ^ "\n") |])

(* Evaluate MLisp code synchronously (simple implementation) *)
let eval_mlisp (code : string) : string =
  init_mlisp_process ();
  mlisp_output_buffer := "";
  send_to_mlisp code;
  (* In a real async implementation, we'd wait for the result.
     For now, return a placeholder indicating evaluation started. *)
  Format.sprintf "Evaluating: %s\n\nResult: [Use REPL for interactive evaluation]" code

(* Get HTML content for REPL webview *)
let get_repl_html () : string =
  {|
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MLisp REPL</title>
  <style>
    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      background-color: var(--vscode-editor-background);
      margin: 0;
      padding: 10px;
      display: flex;
      flex-direction: column;
      height: 100vh;
      box-sizing: border-box;
    }
    #output {
      flex: 1;
      overflow-y: auto;
      padding: 10px;
      background-color: var(--vscode-editor-background);
      border: 1px solid var(--vscode-panel-border);
      border-radius: 4px;
      margin-bottom: 10px;
      font-family: var(--vscode-editor-font-family);
      white-space: pre-wrap;
    }
    .input-line {
      display: flex;
      gap: 5px;
      align-items: center;
    }
    #prompt {
      color: var(--vscode-textLink-foreground);
      font-weight: bold;
      user-select: none;
    }
    #input {
      flex: 1;
      background-color: var(--vscode-input-background);
      color: var(--vscode-input-foreground);
      border: 1px solid var(--vscode-input-border);
      border-radius: 2px;
      padding: 8px;
      font-family: var(--vscode-editor-font-family);
      font-size: var(--vscode-editor-font-size);
      outline: none;
    }
    #input:focus {
      border-color: var(--vscode-focusBorder);
    }
    .output-line {
      margin: 2px 0;
      line-height: 1.4;
    }
    .output-input {
      color: var(--vscode-textLink-foreground);
    }
    .output-result {
      color: var(--vscode-foreground);
    }
    .output-error {
      color: var(--vscode-errorForeground);
    }
    .welcome {
      color: var(--vscode-descriptionForeground);
      font-style: italic;
    }
  </style>
</head>
<body>
  <div id="output">
    <div class="output-line welcome">MLisp REPL</div>
    <div class="output-line welcome">Type expressions and press Enter to evaluate</div>
    <div class="output-line welcome">Use the native MLisp interpreter for evaluation</div>
  </div>
  <div class="input-line">
    <span id="prompt">mlisp&gt;</span>
    <input type="text" id="input" autofocus placeholder="Enter MLisp expression..." />
  </div>
  <script>
    const vscode = acquireVsCodeApi();
    const input = document.getElementById('input');
    const output = document.getElementById('output');

    function addLine(text, className = '') {
      const line = document.createElement('div');
      line.className = 'output-line ' + className;
      line.textContent = text;
      output.appendChild(line);
      output.scrollTop = output.scrollHeight;
    }

    function evaluateCode(code) {
      if (!code.trim()) return;
      addLine('mlisp> ' + code, 'output-input');
      vscode.postMessage({ command: 'eval', code: code });
    }

    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.ctrlKey) {
        e.preventDefault();
        const code = input.value;
        input.value = '';
        evaluateCode(code);
      } else if (e.key === 'Enter' && e.ctrlKey) {
        e.preventDefault();
        input.value += '\\n';
      }
    });

    window.addEventListener('message', event => {
      const message = event.data;
      if (message.type === 'result') {
        addLine(message.output, 'output-result');
      } else if (message.type === 'error') {
        addLine(message.output, 'output-error');
      }
    });

    input.focus();
  </script>
</body>
</html>
|}

(* Create webview panel for REPL *)
let create_repl_panel () : O.t =
  let window = Ojs.get_prop_ascii vscode "window" in
  let view_column = Ojs.get_prop_ascii vscode "ViewColumn" in
  let column_two = Ojs.get_prop_ascii view_column "Two" in

  let panel = Ojs.call window "createWebviewPanel" [|
    Ojs.string_to_js "mlispREPL";
    Ojs.string_to_js "MLisp REPL";
    column_two;
    Ojs.bool_to_js true;
    Ojs.obj [|
      ("enableScripts", Ojs.bool_to_js true);
      ("retainContextWhenHidden", Ojs.bool_to_js true);
    |]
  |] in

  let html = get_repl_html () in
  let webview = Ojs.get_prop_ascii panel "webview" in
  ignore (Ojs.call webview "setHTML" [| Ojs.string_to_js html |]);

  (* Handle messages from webview *)
  let on_message_handler = Ojs.fun_to_js_args (fun msg ->
    let message = Ojs.array_of_js Ojs.t_of_js msg in
    if Array.length message > 0 then (
      let command = Ojs.string_of_js (Ojs.get_prop_ascii message.(0) "command") in
      if command = "eval" then (
        let code = Ojs.string_of_js (Ojs.get_prop_ascii message.(0) "code") in
        let result = eval_mlisp code in
        ignore (Ojs.call webview "postMessage" [| Ojs.obj [|
          ("type", Ojs.string_to_js "result");
          ("output", Ojs.string_to_js result);
        |] |])
      )
    );
    O.unit_to_js ()
  ) in

  ignore (Ojs.call webview "onDidReceiveMessage" [| on_message_handler |]);

  panel

(* Start REPL command - opens webview panel *)
let start_repl (_args : O.t array) : O.t =
  let panel = create_repl_panel () in
  repl_panel := Some panel;
  O.unit_to_js ()

(* Evaluate selection command *)
let evaluate_selection (_args : O.t array) : O.t =
  let window = Ojs.get_prop_ascii vscode "window" in
  let active_text_editor = Ojs.get_prop_ascii window "activeTextEditor" in

  if Ojs.bool_of_js (Ojs.call active_text_editor "isValid" [||]) then (
    let document = Ojs.get_prop_ascii active_text_editor "document" in
    let selection = Ojs.get_prop_ascii active_text_editor "selection" in
    let selected_text = Ojs.call document "getText" [| selection |] in
    let text = Ojs.string_of_js selected_text in

    if text = "" then (
      (* No selection, get current line *)
      let position = Ojs.get_prop_ascii selection "active" in
      let line_num = Ojs.float_of_js (Ojs.get_prop_ascii position "line") in
      let line_int = int_of_float line_num in
      let line_obj = Ojs.call document "lineAt" [| Ojs.int_to_js line_int |] in
      let line_text = Ojs.string_of_js (Ojs.call line_obj "text" [||]) in
      let result = eval_mlisp line_text in
      ignore (Ojs.call window "showInformationMessage" [| Ojs.string_to_js result |])
    ) else (
      let result = eval_mlisp text in
      ignore (Ojs.call window "showInformationMessage" [| Ojs.string_to_js result |])
    )
  ) else (
    ignore (Ojs.call window "showInformationMessage" [| Ojs.string_to_js "No active editor" |])
  );

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

  (* Initialize Node.js modules *)
  init_node_modules ();

  ()

(* Deactivate function - cleanup MLisp process *)
let deactivate () : unit =
  match !mlisp_process with
  | None -> ()
  | Some proc ->
      ignore (Ojs.call proc "kill" [||]);
      mlisp_process := None

(* Export activate function for VSCode *)
let () =
  Js.export "activate" (Js.wrap_callback activate)

(* Export deactivate function *)
let () =
  Js.export "deactivate" (Js.wrap_callback deactivate)
