# MLisp Monorepo + OCaml VSCode Extension Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure MLisp repository as a monorepo and add VSCode language extension written in OCaml using js_of_ocaml (similar to vscode-ocaml-platform architecture).

**Architecture:** Create `packages/` directory structure with three components: `interpreter/` (existing OCaml code), `vscode-ext/` (OCaml-based VSCode extension using js_of_ocaml), and `shared/` (language grammar definitions). The VSCode extension can directly embed the MLisp interpreter for REPL integration.

**Tech Stack:** OCaml 5.0+, Dune 3.3+, js_of_ocaml 6.0+, gen_js_api 1.1.6+, Node.js 18+, VSCode Extension API, TextMate grammars

---

## Overview

This plan transforms the current MLisp repository into a monorepo structure with an OCaml-based VSCode extension:

**Current State:**
```
mlisp/
├── bin/, lib/, stdlib/, test/    # OCaml code scattered
├── docs/
└── README.md
```

**Target State:**
```
mlisp/
├── packages/
│   ├── interpreter/               # OCaml interpreter (moved from root)
│   ├── vscode-ext/                # VSCode extension in OCaml!
│   │   ├── src/                   # OCaml source code
│   │   ├── src-bindings/          # VSCode API bindings (gen_js_api)
│   │   └── syntaxes/              # TextMate grammar (from shared/)
│   └── shared/                    # Language grammar
├── docs/
├── .github/workflows/             # Updated CI
└── README.md
```

**Key Innovation:** Unlike typical VSCode extensions written in TypeScript, this extension is written in OCaml and compiled to JavaScript via js_of_ocaml. This allows:
- Direct embedding of MLisp interpreter for REPL
- Type-safe VSCode API usage
- Single language across the entire project
- Code reuse between interpreter and extension

---

## Task 1: Create Monorepo Directory Structure

**Files:**
- Create: `packages/interpreter/`
- Create: `packages/vscode-ext/`
- Create: `packages/shared/syntax/`

**Step 1: Create package directories**

Run:
```bash
mkdir -p packages/interpreter
mkdir -p packages/vscode-ext
mkdir -p packages/shared/syntax
```

Expected: Directories created successfully

**Step 2: Create placeholder README in each package**

Run:
```bash
echo "# MLisp Interpreter" > packages/interpreter/README.md
echo "# MLisp VSCode Extension (OCaml)" > packages/vscode-ext/README.md
echo "# MLisp Shared Resources" > packages/shared/README.md
```

**Step 3: Commit**

```bash
git add packages/
git commit -m "feat(monorepo): create packages directory structure"
```

---

## Task 2: Move Interpreter Code to packages/interpreter/

**Files:**
- Move: `bin/` → `packages/interpreter/bin/`
- Move: `lib/` → `packages/interpreter/lib/`
- Move: `stdlib/` → `packages/interpreter/stdlib/`
- Move: `test/` → `packages/interpreter/test/`
- Move: `modules/` → `packages/interpreter/modules/`
- Move: `dune-project` → `packages/interpreter/dune-project`
- Move: `mlisp.opam` → `packages/interpreter/mlisp.opam`
- Move: `Makefile` → `packages/interpreter/Makefile`
- Move: `run_tests.sh` → `packages/interpreter/run_tests.sh`
- Move: `.ocamlformat` → `packages/interpreter/.ocamlformat`

**Step 1: Move all OCaml-related directories and files**

Run:
```bash
# Move source code
mv bin packages/interpreter/
mv lib packages/interpreter/
mv stdlib packages/interpreter/
mv test packages/interpreter/
mv modules packages/interpreter/

# Move config files
mv dune-project packages/interpreter/
mv mlisp.opam packages/interpreter/
mv Makefile packages/interpreter/
mv run_tests.sh packages/interpreter/
mv .ocamlformat packages/interpreter/
```

Expected: All files moved

**Step 2: Verify interpreter still builds**

Run:
```bash
cd packages/interpreter && dune build
```

Expected: SUCCESS

**Step 3: Run tests**

Run:
```bash
cd packages/interpreter && ./run_tests.sh
```

Expected: All tests pass

**Step 4: Clean up build artifacts**

Run:
```bash
rm -rf _build
```

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(monorepo): move interpreter code to packages/interpreter/"
```

---

## Task 3: Create Root package.json for Orchestration

**Files:**
- Create: `package.json`

**Step 1: Create root package.json**

Create `package.json`:
```json
{
  "name": "mlisp-monorepo",
  "version": "1.0.0",
  "private": true,
  "description": "MLisp: A Lisp dialect in OCaml - Monorepo",
  "scripts": {
    "build": "npm run build:interpreter && npm run build:vscode",
    "build:interpreter": "cd packages/interpreter && dune build",
    "build:vscode": "cd packages/vscode-ext && dune build",
    "bundle:vscode": "cd packages/vscode-ext && npm run bundle",
    "test": "npm run test:interpreter",
    "test:interpreter": "cd packages/interpreter && ./run_tests.sh",
    "clean": "cd packages/interpreter && dune clean && cd ../vscode-ext && dune clean && rm -rf dist",
    "install:vscode": "cd packages/vscode-ext && npm install",
    "package:vscode": "cd packages/vscode-ext && npm run package"
  },
  "workspaces": [
    "packages/*"
  ],
  "repository": {
    "type": "git",
    "url": "https://github.com/muqiuhan/MLisp.git"
  },
  "author": "Muqiu Han",
  "license": "MPL-2.0"
}
```

**Step 2: Commit**

```bash
git add package.json
git commit -m "feat(monorepo): add root package.json for orchestration"
```

---

## Task 4: Update Root README.md

**Files:**
- Modify: `README.md`

**Step 1: Add monorepo overview section**

Insert after logo/demo, before "Table of Contents":

```markdown
## Monorepo Structure

This repository is organized as a monorepo containing:

| Package | Description | Language |
|---------|-------------|----------|
| [interpreter](packages/interpreter/) | MLisp interpreter implementation | OCaml |
| [vscode-ext](packages/vscode-ext/) | VSCode language extension (OCaml + js_of_ocaml) | OCaml |
| [shared](packages/shared/) | Shared language resources | JSON/TextMate |

### Quick Start

```bash
# Build the interpreter
npm run build:interpreter

# Build VSCode extension
npm run build:vscode && npm run bundle:vscode

# Start the REPL
cd packages/interpreter && dune exec mlisp
```

---

```

**Step 2: Update building instructions**

Modify "Building" section:

From:
```bash
dune build
```

To:
```bash
npm run build
# or
cd packages/interpreter && dune build
```

**Step 3: Update running instructions**

Modify "Running" section:

From:
```bash
dune exec mlisp
```

To:
```bash
cd packages/interpreter && dune exec mlisp
```

**Step 4: Commit**

```bash
git add README.md
git commit -m "docs(monorepo): update README with monorepo structure"
```

---

## Task 5: Create packages/shared/syntax/ - Language Grammar

**Files:**
- Create: `packages/shared/syntax/mlisp.tmLanguage.json`
- Create: `packages/shared/syntax/language-configuration.json`
- Create: `packages/shared/README.md`

**Step 1: Create TextMate grammar**

Create `packages/shared/syntax/mlisp.tmLanguage.json`:

```json
{
  "name": "MLisp",
  "scopeName": "source.mlisp",
  "fileTypes": ["mlisp"],
  "patterns": [
    {
      "name": "comment.line.semicolon.mlisp",
      "match": ";;.*$",
      "captures": {
        "0": {"name": "punctuation.definition.comment.mlisp"}
      }
    },
    {
      "name": "constant.language.boolean.mlisp",
      "match": "\\b(#t|#f)\\b"
    },
    {
      "name": "constant.numeric.mlisp",
      "match": "\\b-?\\d+\\.?\\d*\\b"
    },
    {
      "name": "string.quoted.double.mlisp",
      "begin": "\"",
      "end": "\"",
      "patterns": [
        {
          "name": "constant.character.escape.mlisp",
          "match": "\\\\."
        }
      ]
    },
    {
      "name": "keyword.control.mlisp",
      "match": "\\b(if|cond|else|begin|quote|quasiquote|unquote|unquote-splicing)\\b"
    },
    {
      "name": "keyword.control.special.mlisp",
      "match": "\\b(let|let\\*|letrec|define|defun|defmacro|set!|setq)\\b"
    },
    {
      "name": "keyword.operator.mlisp",
      "match": "\\b(lambda|module|import|export|ocall)\\b"
    },
    {
      "name": "keyword.operator.rest-parameter.mlisp",
      "match": "&rest"
    },
    {
      "name": "constant.language.nil.mlisp",
      "match": "\\bnil\\b"
    },
    {
      "match": "\\b([a-zA-Z][a-zA-Z0-9-*/<>!=?+]+)\\b",
      "captures": {
        "1": {"name": "entity.name.function.mlisp"}
      }
    },
    {
      "name": "punctuation.definition.expression.begin.mlisp",
      "match": "\\("
    },
    {
      "name": "punctuation.definition.expression.end.mlisp",
      "match": "\\)"
    },
    {
      "name": "punctuation.definition.quote.mlisp",
      "match": "'"
    },
    {
      "name": "punctuation.definition.quasiquote.mlisp",
      "match": "`"
    },
    {
      "name": "punctuation.definition.unquote.mlisp",
      "match": ","
    },
    {
      "name": "punctuation.definition.unquote-splicing.mlisp",
      "match": ",@"
    }
  ]
}
```

**Step 2: Create language configuration**

Create `packages/shared/syntax/language-configuration.json`:

```json
{
  "comments": {
    "lineComment": ";;"
  },
  "brackets": [
    ["(", ")"],
    ["[", "]"],
    ["{", "}"]
  ],
  "autoClosingPairs": [
    {"open": "(", "close": ")"},
    {"open": "[", "close": "]"},
    {"open": "{", "close": "}"},
    {"open": "\"", "close": "\""}
  ],
  "surroundingPairs": [
    ["(", ")"],
    ["[", "]"],
    ["{", "}"],
    ["\"", "\""]
  ],
  "folding": {
    "markers": {
      "start": "^\\s*\\(;",
      "end": "^\\s*;\\)"
    }
  },
  "wordPattern": "(?!\\b)[a-zA-Z0-9-*/<>!=?+]+",
  "indentationRules": {
    "increaseIndentPattern": "\\(.*[^;\\)]$",
    "decreaseIndentPattern": "^\\s*\\)"
  }
}
```

**Step 3: Create shared package README**

Create `packages/shared/README.md`:

```markdown
# MLisp Shared Resources

Language definition files shared across editor extensions.

## Contents

- `syntax/mlisp.tmLanguage.json` - TextMate grammar
- `syntax/language-configuration.json` - Language configuration

## Usage

Referenced by:
- `packages/vscode-ext/syntaxes/` (symlink or copy)
- Future editor extensions
```

**Step 4: Commit**

```bash
git add packages/shared/
git commit -m "feat(shared): add MLisp TextMate grammar and language config"
```

---

## Task 6: Create VSCode Extension - dune-project

**Files:**
- Create: `packages/vscode-ext/dune-project`

**Step 1: Create dune-project for VSCode extension**

Create `packages/vscode-ext/dune-project`:

```lisp
(lang dune 3.3)

(name vscode-mlisp)

(source
 (github muqiuhan/MLisp))

(package
 (name vscode-mlisp)
 (synopsis "VSCode extension for MLisp")
 (depends
  (ocaml (>= 5.0))
  (js_of_ocaml (>= 6.0))
  (gen_js_api (= 1.1.6))
  (mlisp (>= 0.0.44))
  (promise_jsoo (>= 0.4.3))
  (jsonoo (>= 0.3))
  (ocaml-version (>= 4.0))
  (ppxlib (>= 0.36))))
```

**Step 2: Commit**

```bash
git add packages/vscode-ext/dune-project
git commit -m "feat(vscode-ext): add dune-project with js_of_ocaml dependencies"
```

---

## Task 7: Create VSCode Extension - package.json

**Files:**
- Create: `packages/vscode-ext/package.json`

**Step 1: Create package.json**

Create `packages/vscode-ext/package.json`:

```json
{
  "name": "mlisp-vscode",
  "displayName": "MLisp Language Support",
  "description": "Syntax highlighting and REPL for MLisp",
  "version": "0.1.0",
  "publisher": "mlisp",
  "engines": {
    "vscode": "^1.80.0"
  },
  "categories": ["Programming Languages"],
  "activationEvents": [
    "onStartupFinished"
  ],
  "main": "./dist/vscode_mlisp.bc.js",
  "contributes": {
    "languages": [{
      "id": "mlisp",
      "aliases": ["MLisp", "mlisp"],
      "extensions": [".mlisp"],
      "configuration": "./language-configuration.json"
    }],
    "grammars": [{
      "language": "mlisp",
      "scopeName": "source.mlisp",
      "path": "./syntaxes/mlisp.tmLanguage.json"
    }],
    "commands": [
      {
        "command": "mlisp.startREPL",
        "title": "MLisp: Start REPL"
      },
      {
        "command": "mlisp.evaluateSelection",
        "title": "MLisp: Evaluate Selection"
      }
    ],
    "keybindings": [
      {
        "command": "mlisp.evaluateSelection",
        "key": "ctrl+enter",
        "when": "editorLangId == mlisp"
      }
    ]
  },
  "scripts": {
    "check": "biome check",
    "fix": "biome check --fix",
    "bundle": "esbuild _build/default/src/vscode_mlisp.bc.js --bundle --external:vscode --minify --outdir=dist --platform=node --target=node18",
    "package": "vsce package --out mlisp-vscode.vsix",
    "install:ext": "code --force --install-extension mlisp-vscode.vsix"
  },
  "devDependencies": {
    "@biomejs/biome": "^1.8.0",
    "esbuild": "^0.20.0",
    "@vscode/vsce": "^2.24.0"
  }
}
```

**Step 2: Commit**

```bash
git add packages/vscode-ext/package.json
git commit -m "feat(vscode-ext): add package.json for VSCode extension"
```

---

## Task 8: Create VSCode API Bindings

**Files:**
- Create: `packages/vscode-ext/src-bindings/vscode/dune`
- Create: `packages/vscode-ext/src-bindings/vscode/vscode.mli`
- Create: `packages/vscode-ext/src-bindings/vscode/vscode.ml`
- Create: `packages/vscode-ext/src-bindings/vscode/vscode_stub.js`

**Step 1: Create bindings directory and dune file**

Run:
```bash
mkdir -p packages/vscode-ext/src-bindings/vscode
```

Create `packages/vscode-ext/src-bindings/vscode/dune`:

```lisp
(library
 (name vscode_bindings)
 (public_name vscode.mlisp_bindings)
 (modules vscode)
 (libraries js_of_ocaml gen_js_api promise_jsoo jsonoo)
 (js_of_ocaml)
 (preprocess (pps gen_js_api)))
```

**Step 2: Create vscode_stub.js**

Create `packages/vscode-ext/src-bindings/vscode/vscode_stub.js`:

```javascript
// Provides global 'vscode' object for js_of_ocaml binding
// This is loaded by VSCode extension host
```

**Step 3: Create vscode.mli (VSCode API types)**

Create `packages/vscode-ext/src-bindings/vscode/vscode.mli`:

```ocaml
(* VSCode API bindings for MLisp extension
   Generated using gen_js_api for type-safe interop *)

open Js_of_ocaml.Js

(* Core types *)
type extensionContext
type disposable
type command
type position
type range
type textEditor
type textDocument

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
```

**Step 4: Create vscode.ml (Implementations)**

Create `packages/vscode-ext/src-bindings/vscode/vscode.ml`:

```ocaml
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
```

**Step 5: Install npm dependencies**

Run:
```bash
cd packages/vscode-ext
npm install
```

Expected: Dependencies installed successfully

**Step 6: Verify bindings compile**

Run:
```bash
dune build
```

Expected: Bindings compile without errors

**Step 7: Commit**

```bash
git add packages/vscode-ext/src-bindings/
git commit -m "feat(vscode-ext): add VSCode API bindings using gen_js_api"
```

---

## Task 9: Create Main Extension Code

**Files:**
- Create: `packages/vscode-ext/src/dune`
- Create: `packages/vscode-ext/src/vscode_mlisp.ml`
- Create: `packages/vscode-ext/src/vscode_mlisp.mli`

**Step 1: Create src dune file**

Run:
```bash
mkdir -p packages/vscode-ext/src
```

Create `packages/vscode-ext/src/dune`:

```lisp
(executable
 (name vscode_mlisp)
 (public_name vscode_mlisp.bc)
 (modules vscode_mlisp)
 (libraries vscode_bindings js_of_ocaml)
 (js_of_ocaml)
 (preprocess (pps gen_js_api))
 (modes js))
```

**Step 2: Create extension entry point**

Create `packages/vscode-ext/src/vscode_mlisp.ml`:

```ocaml
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
```

**Step 3: Create mli file**

Create `packages/vscode-ext/src/vscode_mlisp.mli`:

```ocaml
(* MLisp VSCode Extension *)

(* activate : ExtensionContext.t -> Ojs.t
 * Called by VSCode when the extension is activated *)
val activate : Ojs.t -> Ojs.t
```

**Step 4: Build extension**

Run:
```bash
cd packages/vscode-ext && dune build
```

Expected: `vscode_mlisp.bc.js` generated in `_build/default/src/`

**Step 5: Bundle with esbuild**

Run:
```bash
npm run bundle
```

Expected: `dist/vscode_mlisp.bc.js` created

**Step 6: Commit**

```bash
git add packages/vscode-ext/src/
git commit -m "feat(vscode-ext): add main extension code with commands"
```

---

## Task 10: Link Syntax Files and Finalize Extension

**Files:**
- Create: `packages/vscode-ext/syntaxes/mlisp.tmLanguage.json`
- Create: `packages/vscode-ext/language-configuration.json`
- Create: `packages/vscode-ext/.vscodeignore`

**Step 1: Create syntaxes directory and link files**

Run:
```bash
mkdir -p packages/vscode-ext/syntaxes
ln -s ../../../shared/syntax/mlisp.tmLanguage.json packages/vscode-ext/syntaxes/
```

Or copy if symlinks cause issues:
```bash
cp packages/shared/syntax/mlisp.tmLanguage.json packages/vscode-ext/syntaxes/
```

**Step 2: Copy language configuration**

Run:
```bash
cp packages/shared/syntax/language-configuration.json packages/vscode-ext/
```

**Step 3: Create .vscodeignore**

Create `packages/vscode-ext/.vscodeignore`:

```
.vscode/**
.vscode-test/**
src/**
src-bindings/**
.gitignore**
esbuild.config.mjs
**/*.ts
**/*.map
dune
dune-project
*.opam
_git**
.ocamlformat
syndicates disturbances
syntaxes
```

**Step 4: Create extension README**

Create `packages/vscode-ext/README.md`:

```markdown
# MLisp VSCode Extension

VSCode language support for MLisp, written entirely in OCaml using js_of_ocaml.

## Features

- Syntax highlighting for `.mlisp` files
- REPL integration (coming soon)
- Evaluate code directly from editor

## Installation

```bash
# From source
cd packages/vscode-ext
npm run bundle && npm run package

# Install locally
code --force --install-extension mlisp-vscode.vsix
```

## Development

```bash
# Install dependencies
npm install

# Build OCaml to JavaScript
dune build

# Bundle with esbuild
npm run bundle

# Press F5 in VSCode to test
```

## Architecture

This extension is unique - it's written in OCaml and compiled to JavaScript via js_of_ocaml:

```
OCaml Source (vscode_mlisp.ml)
    ↓ js_of_ocaml
JavaScript Bytecode (.bc.js)
    ↓ esbuild
Bundled Extension
```

This allows direct embedding of the MLisp interpreter for future REPL features.

## License

MPL-2.0
```

**Step 5: Final build and test**

Run:
```bash
cd packages/vscode-ext
dune build
npm run bundle
ls -la dist/
```

Expected: `dist/vscode_mlisp.bc.js` exists

**Step 6: Package extension**

Run:
```bash
npm run package
```

Expected: `mlisp-vscode.vsix` created

**Step 7: Commit**

```bash
git add packages/vscode-ext/
git commit -m "feat(vscode-ext): finalize extension with syntax files and packaging"
```

---

## Task 11: Update CI/CD for Monorepo

**Files:**
- Create: `.github/workflows/ci.yml`

**Step 1: Create monorepo CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  interpreter:
    name: Interpreter (OCaml)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: packages/interpreter

    steps:
      - uses: actions/checkout@v3

      - name: Set up OCaml
        uses: ocaml/setup-ocaml@v2
        with:
          ocaml-compiler: 5.0

      - name: Install dependencies
        run: opam install . --deps-only

      - name: Build
        run: dune build

      - name: Run tests
        run: ./run_tests.sh

  vscode:
    name: VSCode Extension (OCaml + js_of_ocaml)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: packages/vscode-ext

    steps:
      - uses: actions/checkout@v3

      - name: Set up OCaml
        uses: ocaml/setup-ocaml@v2
        with:
          ocaml-compiler: 5.0

      - name: Install OCaml dependencies
        run: opam install . --deps-only

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: 18

      - name: Install npm dependencies
        run: npm install

      - name: Build extension
        run: dune build

      - name: Bundle extension
        run: npm run bundle

      - name: Package extension
        run: npm run package
```

**Step 2: Commit**

```bash
git add .github/workflows/
git commit -m "ci(monorepo): add CI workflow for interpreter and vscode extension"
```

---

## Task 12: Update .gitignore and Root Files

**Files:**
- Modify: `.gitignore`
- Create: `docs/monorepo-migration.md`

**Step 1: Add monorepo-specific ignores**

Add to `.gitignore`:

```
# Node.js (VSCode extension)
node_modules/
packages/vscode-ext/node_modules/
*.vsix

# js_of_ocaml build artifacts
*.bc.js
*.bc.js.map

# VSCode
.vscode-test/
dist/

# esbuild
packages/vscode-ext/dist/
```

**Step 2: Create migration guide**

Create `docs/monorepo-migration.md`:

```markdown
# Monorepo Migration Guide

## What Changed

The MLisp repository has been restructured as a monorepo:

- **Before**: Root contained `bin/`, `lib/`, `stdlib/`, etc.
- **After**: Code organized under `packages/` directory

## New Structure

| Package | Purpose | Language |
|---------|---------|----------|
| `interpreter/` | MLisp interpreter | OCaml |
| `vscode-ext/` | VSCode extension (js_of_ocaml) | OCaml |
| `shared/` | Language grammar | JSON |

## Migration Impact

### Building

```bash
# Old
dune build

# New
npm run build
# or
cd packages/interpreter && dune build
cd packages/vscode-ext && dune build
```

### Running

```bash
# Old
dune exec mlisp

# New
cd packages/interpreter && dune exec mlisp
```

### VSCode Extension

The VSCode extension is now written in OCaml and compiled via js_of_ocaml:

```bash
cd packages/vscode-ext
dune build        # OCaml → JavaScript bytecode
npm run bundle    # esbuild packaging
npm run package   # Create .vsix
```
```

**Step 3: Update root README with migration link**

Add to `README.md` in monorepo section:

```markdown
> **Note:** See [docs/monorepo-migration.md](docs/monorepo-migration.md) for migration details.
```

**Step 4: Commit**

```bash
git add .gitignore docs/
git commit -m "docs(monorepo): add migration guide and update gitignore"
```

---

## Task 13: Final Verification

**Files:**
- Test: All components

**Step 1: Full build test**

Run:
```bash
npm run build
```

Expected: Both interpreter and extension build successfully

**Step 2: Test interpreter**

Run:
```bash
cd packages/interpreter && dune exec mlisp
```

Type: `(+ 1 2)`
Expected: `3`

**Step 3: Verify extension package**

Run:
```bash
ls -la packages/vscode-ext/mlisp-vscode.vsix
```

Expected: File exists and is > 0 bytes

**Step 4: Install and test extension (optional)**

Run:
```bash
cd packages/vscode-ext && code --install-extension mlisp-vscode.vsix
```

**Step 5: Final summary commit**

```bash
git commit --allow-empty -m "feat(monorepo): monorepo migration complete

- Restructured repository as monorepo with packages/
- Moved interpreter to packages/interpreter/
- Added VSCode extension to packages/vscode-ext/ (OCaml + js_of_ocaml)
- Added shared language resources to packages/shared/
- VSCode extension written in OCaml using js_of_ocaml and gen_js_api
- Updated CI/CD for monorepo structure
- Updated documentation"
```

---

## Summary of Changes

### Files Created
```
packages/
├── interpreter/          # Moved from root (OCaml interpreter)
├── vscode-ext/           # NEW (OCaml + js_of_ocaml)
│   ├── src/
│   │   ├── vscode_mlisp.{ml,mli}    # Main extension code
│   │   └── dune
│   ├── src-bindings/
│   │   └── vscode/
│   │       ├── vscode.{ml,mli}      # VSCode API bindings
│   │       ├── vscode_stub.js
│   │       └── dune
│   ├── syntaxes/         # TextMate grammar
│   ├── package.json
│   └── dune-project
└── shared/               # NEW
    └── syntax/
        ├── mlisp.tmLanguage.json
        └── language-configuration.json

docs/
└── monorepo-migration.md

package.json              # Root orchestration
.github/workflows/ci.yml  # Updated CI
```

### Key Technical Decisions

| Aspect | Choice | Reason |
|--------|--------|--------|
| Extension Language | OCaml | Same as interpreter, type-safe |
| JS Compilation | js_of_ocaml | Proven by vscode-ocaml-platform |
| API Bindings | gen_js_api | Type-safe JavaScript interop |
| Bundling | esbuild | Fast, handles vscode external |
| Version Management | Independent | Each package has own version |

### Future Enhancements

- [ ] Embed MLisp interpreter in VSCode extension for real REPL
- [ ] Add syntax highlighting tests
- [ ] Add more editor commands (format, etc.)
- [ ] Publish to VSCode Marketplace
- [ ] Add LSP support
- [ ] Add debugger integration

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        MLisp Monorepo                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              packages/interpreter/                         │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │  OCaml Interpreter                                   │ │ │
│  │  │  • lib/{ast,lexer,eval,object,macro,primitives}    │ │ │
│  │  │  • bin/mlisp.ml                                      │ │ │
│  │  │  • stdlib/                                           │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────┘ │
│                              │                                 │
│                              │ Used by                         │
│                              ▼                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              packages/vscode-ext/                          │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │  OCaml Source                                        │ │ │
│  │  │  • src/vscode_mlisp.ml  (extension entry)           │ │ │
│  │  │  • src-bindings/vscode/vscode.ml  (VSCode API)      │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  │                              │                             │ │
│  │                              │ js_of_ocaml                 │ │
│  │                              ▼                             │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │  JavaScript (.bc.js)                                 │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  │                              │                             │ │
│  │                              │ esbuild                     │ │
│  │                              ▼                             │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │  dist/vscode_mlisp.bc.js  (bundled)                  │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              packages/shared/syntax/                       │ │
│  │  • mlisp.tmLanguage.json                                  │ │
│  │  • language-configuration.json                            │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Verification Checklist

- [ ] `npm run build` builds both interpreter and extension
- [ ] `npm run test` runs all tests successfully
- [ ] VSCode extension package `mlisp-vscode.vsix` is created
- [ ] Syntax highlighting works for `.mlisp` files
- [ ] CI passes on GitHub Actions
- [ ] Documentation is complete
