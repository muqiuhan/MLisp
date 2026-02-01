# VSCode Extension Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement functional MLisp VSCode extension with syntax highlighting and basic language support, built with OCaml using js_of_ocaml compilation.

**Architecture:** The extension is written entirely in OCaml and compiled to JavaScript via js_of_ocaml. It uses gen_js_api for type-safe VSCode API bindings. The extension loads syntax grammar from shared resources and can potentially embed the MLisp interpreter for REPL functionality.

**Tech Stack:** OCaml 5.0+, Dune 3.3+, js_of_ocaml 6.0+, gen_js_api 1.1.6+, Node.js 18+, esbuild 0.20+, VSCode Extension API, TextMate grammars

---

## Overview

The VSCode extension skeleton is already created but lacks:
1. OCaml dependencies (js_of_ocaml, gen_js_api, etc.) not installed
2. Extension cannot be compiled yet due to missing dependencies
3. Syntax highlighting needs testing and verification
4. Extension needs to be actually buildable and testable

This plan focuses on getting the extension to a working state with proper syntax highlighting as the first milestone.

---

## Task 1: Install Development Dependencies

**Files:**
- System: opam packages, npm packages

**Step 1: Switch to appropriate OCaml version**

Run:
```bash
opam switch create . 5.0 --no-install
```

Expected: Creates opam switch for OCaml 5.0

**Step 2: Install OCaml dependencies**

Run:
```bash
cd packages/vscode-ext
opam install . --deps-only --with-test
```

Expected: Installs js_of_ocaml, gen_js_api, promise_jsoo, jsonoo, ppxlib, ocaml-version

**Step 3: Install npm dependencies**

Run:
```bash
npm install
```

Expected: Installs esbuild, @vscode/vsce, @biomejs/biome

**Step 4: Verify installations**

Run:
```bash
opam list
```

Expected: Shows js_of_ocaml, gen_js_api, promise_jsoo, jsonoo installed

**Step 5: Commit**

```bash
git add packages/vscode-ext/package-lock.json
git add packages/vscode-ext/package.json
git commit -m "chore(vscode-ext): install development dependencies"
```

---

## Task 2: Fix OCaml Compilation Errors

**Files:**
- Modify: `packages/vscode-ext/src-bindings/vscode/vscode.ml`
- Modify: `packages/vscode-ext/src-bindings/vscode/vscode.mli`
- Modify: `packages/vscode-ext/src/vscode_mlisp.ml`

**Step 1: Read and analyze compilation errors**

Run:
```bash
cd packages/vscode-ext && dune build 2>&1 | head -50
```

Expected: Shows specific OCaml type errors to fix

**Step 2: Fix vscode.ml compilation errors**

The current implementation has syntax errors. Fix them:

Common issues to fix:
- `Ojs.variable "ctx"` should be just the parameter name
- Array.concat syntax: `[@@ ...]` is incorrect, use `Array.append`
- Function application syntax issues

Create corrected `packages/vscode-ext/src-bindings/vscode/vscode.ml`:

```ocaml
(* VSCode API bindings implementation *)

let vscode = Ojs.variable "vscode"

module ExtensionContext = struct
  type t = Ojs.t

  let subscriptions (ctx : t) =
    Ojs.(get ctx "subscriptions")
    |> Ojs.to_array

  let globalState (ctx : t) =
    Ojs.(get ctx "globalState")

  let workspaceState (ctx : t) =
    Ojs.(get ctx "workspaceState")
end

module Disposable = struct
  type t = Ojs.t

  let from (disposables : t array) =
    let arr = Array.map (fun x -> x) disposables in
      Ojs.call (Ojs.method vscode "Disposable.from") vscode [| arr |]

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
      (Array.append [| Js.string command |] args)
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

**Step 3: Fix vscode_mlisp.ml compilation errors**

Create corrected `packages/vscode-ext/src/vscode_mlisp.ml`:

```ocaml
(* MLisp VSCode Extension - Main Entry Point *)

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
      ignore (Window.showInformationMessage ~message:"MLisp extension activated!" ())

(* Start REPL command *)
let start_repl () =
  init_output ();
  match !output_channel with
  | None -> ignore (Window.showInformationMessage ~message:"REPL not available" ())
  | Some channel ->
      ignore (Ojs.call (Ojs.method channel "append") channel [| Js.string "MLisp REPL Started\n" |]);
      ignore (Ojs.call (Ojs.method channel "show") channel [||]);
      Js.undefined

(* Evaluate selection command *)
let evaluate_selection () =
  init_output ();
  ignore (Window.showInformationMessage ~message:"Evaluation coming soon!" ());
  Js.undefined

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
  (* Note: don't dispose subscriptions, we want to keep them *)
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

**Step 4: Build and verify**

Run:
```bash
dune build
```

Expected: SUCCESS - no compilation errors

**Step 5: Commit**

```bash
git add packages/vscode-ext/src-bindings/vscode/
git add packages/vscode-ext/src/
git commit -m "fix(vscode-ext): fix OCaml compilation errors"
```

---

## Task 3: Bundle and Test Extension Locally

**Files:**
- Create: `packages/vscode-ext/dist/vscode_mlisp.bc.js`

**Step 1: Bundle the extension**

Run:
```bash
npm run bundle
```

Expected: Creates `dist/vscode_mlisp.bc.js`

**Step 2: Verify bundle exists**

Run:
```bash
ls -la dist/
```

Expected: Shows `vscode_mlisp.bc.js` file

**Step 3: Check extension can be loaded**

Create test file `/tmp/test_mlisp.mlisp`:

```lisp
;; Simple MLisp test
(define x 42)
(print "Hello from MLisp!")
(+ 1 2)
```

**Step 4: Install extension locally**

Run:
```bash
npm run package:ext
```

Expected: Creates and installs `mlisp-vscode.vsix`

**Step 5: Verify installation**

Run:
```bash
code --list-extensions | grep mlisp
```

Expected: Shows installed MLisp extension

**Step 6: Uninstall for development**

Run:
```bash
code --uninstall-extension mlisp-vscode
```

Expected: Extension uninstalled

**Step 7: Clean up**

Run:
```bash
rm mlisp-vscode.vsix
```

**Step 8: Commit**

```bash
git add packages/vscode-ext/
git commit -m "test(vscode-ext): bundle extension and verify local loading"
```

---

## Task 4: Test Syntax Highlighting

**Files:**
- Create: `test/syntax_highlighting.mlisp`
- Test: Manual verification in VSCode

**Step 1: Create syntax highlighting test file**

Create `test/syntax_highlighting.mlisp`:

```lisp
;; MLisp Syntax Highlighting Test
;; Comments
;; This is a comment
;; Keywords: if, cond, else, begin, quote, quasiquote

;; Boolean literals
#t
#f

;; Numbers
42
-17
3.14

;; Strings
"hello world"
"escaped \"quote\""

;; Symbols and Keywords
(define x 42)
(lambda (x) (+ x 1))
if
cond
else
begin
quote
quasiquote
unquote
unquote-splicing
let
let*
letrec
define
defun
defmacro
set!
setq
lambda
module
import
export
ocall
&rest

;; S-expressions
(define factorial (n)
  (if (== n 0)
      1
      (* n (factorial (- n 1)))))

;; Quasiquoting
(define x 42)
`(1 ,x 3)  ;; Should show: (1 42 3)

;; Unquote-splicing
(define nums '(2 3 4))
`(1 ,@nums 5)  ;; Should show: (1 2 3 4 5)

;; Nested quote
`` `(1 ,,x)  ;; Should show: `(1 ,42)

;; Function calls
(ocall String.length "hello")
(ocall List.length '(1 2 3))
```

**Step 2: Temporarily install extension for testing**

Run:
```bash
cd packages/vscode-ext
npm run package:ext
```

**Step 3: Open test file in VSCode**

Run:
```bash
code test/syntax_highlighting.mlisp
```

**Step 4: Verify syntax highlighting**

Manually verify in VSCode:
- Comments are gray/italic
- Keywords (`if`, `define`, `lambda`, etc.) are highlighted
- Booleans `#t`, `#f` are highlighted
- Numbers are highlighted
- Strings are highlighted
- Symbols/functions are highlighted
- Brackets `()` are highlighted

**Step 5: Test bracket matching**

Type in VSCode:
```lisp
(((nested)))
```

Expected: Brackets auto-highlight when cursor is next to them

**Step 6: Test auto-closing pairs**

Type an open parenthesis `(` and verify `)` is auto-inserted.

**Step 7: Uninstall extension after testing**

Run:
```bash
code --uninstall-extension mlisp-vscode
```

**Step 8: Clean up**

Run:
```bash
rm mlisp-vscode.vsix
```

**Step 9: Delete test file**

Run:
```bash
rm test/syntax_highlighting.mlisp
```

**Step 10: Commit**

```bash
git add test/syntax_highlighting.mlisp
git commit -m "test(vscode-ext): add syntax highlighting test file"
```

---

## Task 5: Improve TextMate Grammar

**Files:**
- Modify: `packages/shared/syntax/mlisp.tmLanguage.json`

**Step 1: Read current grammar**

Run:
```bash
cat packages/shared/syntax/mlisp.tmLanguage.json
```

**Step 2: Identify improvements**

Current grammar covers basics but could add:
- Character literals (from `int->char`)
- More escape sequences in strings
- Better symbol recognition (numbers in symbols like `temp2`)
- Distinguish between different function types

**Step 3: Enhanced grammar**

Replace `packages/shared/syntax/mlisp.tmLanguage.json` with:

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
      "name": "comment.block.mlisp",
      "begin": "(;",
      "end": ";)",
      "patterns": [
        {
          "name": "comment.block.mlisp",
          "match": ";.*;"
        }
      ]
    },
    {
      "name": "constant.language.boolean.mlisp",
      "match": "\\b(#t|#f)\\b"
    },
    {
      "name": "constant.language.character.mlisp",
      "match": "\\\#([A-Za-z])"
    },
    {
      "name": "constant.numeric.integer.mlisp",
      "match": "\\b-?\\d+\\b"
    },
    {
      "name": "constant.numeric.float.mlisp",
      "match": "\\b-?\\d+\\.\\d+\\b"
    },
    {
      "name": "string.quoted.double.mlisp",
      "begin": "\"",
      "end": "\"",
      "patterns": [
        {
          "name": "constant.character.escape.mlisp",
          "match": "\\\\(.|\\$\\|n\"|[0-7]"
        },
        {
          "name": "constant.character.escape.octal.mlisp",
          "match": "\\\\([0-7][0-7][0-7]"
        },
        {
          "name": "constant.character.escape.hex.mlisp",
          "match": "\\\\x([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])"
        },
        {
          "name": "constant.character.escape.unicode.mlisp",
          "match": "\\\\u\\{[0-9a-fA-F]+\\}"
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
      "name": "keyword.control.special.return.mlisp",
      "match": "\\b(return)\\b"
    },
    {
      "name": "keyword.operator.rest-parameter.mlisp",
      "match": "&rest"
    },
    {
      "name": "keyword.operator.comparison.mlisp",
      "match": "\\b(==|!=|<|>|<=|>=)\\b"
    },
    {
      "name": "keyword.operator.arithmetic.mlisp",
      "match": "\\b(\\+|\\-|\\*|/|%|\\^)\\b"
    },
    {
      "name": "constant.language.nil.mlisp",
      "match": "\\bnil\\b"
    },
    {
      "name": "constant.language.empty.mlisp",
      "match": "'\\(\\)'"
    },
    {
      "match": "\\b([a-zA-Z][a-zA-Z0-9-*/<>!=?+:]+)\\b",
      "captures": {
        "1": {"name": "entity.name.function.mlisp"}
      }
    },
    {
      "match": "\\b([a-zA-Z][a-zA-Z0-9-*/<>!=?+:]*[?!)\\b",
      "captures": {
        "1": {"name": "entity.name.function.predicate.mlisp"},
        "2": {"name": "punctuation.definition.predicate.mlisp"}
      }
    },
    {
      "name": "variable.other.mlisp",
      "match": "\\b[a-zA-Z_][a-zA-Z0-9_]*\\b"
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
      "match: ",@"
    },
    {
      "name": "constant.numeric.radix.mlisp",
      "match": "\\b[bB][xX][0-9a-fA-F]+\\b"
    },
    {
      "name": "constant.numeric.octal.mlisp",
      "match": "\\b[oO][0-7]+\\b"
    },
    {
      "name": "constant.numeric.binary.mlisp",
      "match": "\\b[bB][01]+\\b"
    }
  ]
}
```

**Step 4: Update VSCode extension with new grammar**

Run:
```bash
cp packages/shared/syntax/mlisp.tmLanguage.json packages/vscode-ext/syntaxes/
```

**Step 5: Test syntax highlighting**

Reopen `test/syntax_highlighting.mlisp` in VSCode and verify new highlighting works:
- Character literals like `\#A` are highlighted
- Float numbers like `3.14` are highlighted separately from integers
- Predicates ending in `?` are highlighted
- Radix notation like `0xFF` is highlighted

**Step 6: Commit**

```bash
git add packages/shared/syntax/mlisp.tmLanguage.json
git commit -m "feat(vscode-ext): enhance TextMate grammar with more patterns"
```

---

## Task 6: Add Snippets for MLisp

**Files:**
- Create: `packages/vscode-ext/snippets/mlisp.json`

**Step 1: Create snippets directory**

Run:
```bash
mkdir -p packages/vscode-ext/snippets
```

**Step 2: Create snippets file**

Create `packages/vscode-ext/snippets/mlisp.json`:

```json
{
  "Define function": {
    "prefix": "def",
    "body": [
      "(defun ${1:function_name} (${2:params})",
      "  ${0:/* body */})"
    ],
    "description": "Define a named function"
  },
  "Define variable": {
    "prefix": "defvar",
    "body": [
      "(define ${1:variable} ${2:value})"
    ],
    "description": "Define a variable"
  },
  "Lambda": {
    "prefix": "lambda",
    "body": [
      "(lambda (${1:params}) ${0:/* body */})"
    ],
    "description": "Anonymous lambda function"
  },
  "If expression": {
    "prefix": "if",
    "body": [
      "(if ${1:condition} ${2:true_value} ${3:false_value})"
    ],
    "description": "If-then-else expression"
  },
  "Let expression": {
    "prefix": "let",
    "body": [
      "(let ((${1:var1} ${2:expr1})",
      "     (${3:var2} ${4:expr2}))",
      "  ${5:body})"
    ],
    "description": "Let binding"
  },
  "Cond": {
    "prefix": "cond",
    "body": [
      "(cond ((${1:test1} ${2:result1})",
      "       (${3:test2} ${4:result2})",
      "       (${5:test3} ${6:result3}))"
    ],
    "description": "Conditional expression"
  },
  "Module": {
    "prefix": "module",
    "body": [
      "(module ${1:module_name} (export ${2:exports})",
      "  ${0:/* module body */})"
    ],
    "description": "Module definition"
  },
  "Macro": {
    "prefix": "defmacro",
    "body": [
      "(defmacro ${1:macro_name} (${2:params})",
      "  ${0:/* macro body */})"
    ],
    "description": "Define a macro"
  },
  "OCall String.length": {
    "prefix": "sl",
    "body": [
      "(ocall String.length \"${1:string}\")"
    ],
    "description": "OCaml String.length"
  },
  "OCall String.concat": {
    "prefix": "sc",
    "body": [
      "(ocall String.concat \"${1:string1}\" \"${2:string2}\")"
    ],
    "description": "OCaml String.concat"
  },
  "OCall List.length": {
    "prefix": "ll",
    "body": [
      "(ocall List.length '(${1:list}))"
    ],
    "description": "OCaml List.length"
  },
  "Factorial": {
    "prefix": "fact",
    "body": [
      "(defun ${1:n} (if (== ${1:n} 0) 1 (* ${1:n} (factorial (- ${1:n} 1)))))"
    ],
    "description": "Factorial function"
  }
}
```

**Step 3: Update package.json to include snippets**

Check if `contributes` in package.json includes snippets reference. Add if missing:

```json
"contributes": {
  ...
  "snippets": [
    {
      "language": "mlisp",
      "path": "./snippets/mlisp.json"
    }
  ]
}
```

**Step 4: Test snippets**

In VSCode with MLisp extension installed:
1. Open a `.mlisp` file
2. Type `def` and press Tab - should expand to define function template
3. Type `sl` and press Tab - should expand to String.length call
4. Type `fact` and press Tab - should expand to factorial template

**Step 5: Commit**

```bash
git add packages/vscode-ext/snippets/
git add packages/vscode-ext/package.json
git commit -m "feat(vscode-ext): add code snippets for MLisp"
```

---

## Task 7: Create Extension Development Documentation

**Files:**
- Create: `packages/vscode-ext/DEVELOPMENT.md`

**Step 1: Create development guide**

Create `packages/vscode-ext/DEVELOPMENT.md`:

```markdown
# VSCode Extension Development Guide

## Building the Extension

### Prerequisites

- OCaml 5.0+
- Node.js 18+
- opam (with 5.0 switch)

### Build Steps

```bash
cd packages/vscode-ext

# Install dependencies (first time only)
opam install . --deps-only
npm install

# Build OCaml to JavaScript
dune build

# Bundle for VSCode
npm run bundle

# Package as .vsix
npm run package
```

### File Structure

```
packages/vscode-ext/
├── src/                      # Extension entry point
│   ├── vscode_mlisp.ml       # Main activate/deactivate
│   └── dune                 # Build config
├── src-bindings/             # VSCode API bindings
│   └── vscode/
│       ├── vscode.ml        # API implementations
│       ├── vscode.mli       # API signatures
│       ├── vscode_stub.js   # JS stub
│       └── dune             # Build config
├── syntaxes/                  # TextMate grammar (from shared/)
├── snippets/                 # Code snippets
├── package.json              # Extension manifest
├── dune-project              # OCaml package config
└── language-configuration.json  # Language config (from shared/)
```

## Testing the Extension

### Local Testing

1. Press F5 in VSCode (with mlisp repo open)
2. Extension Development Host will open
3. Open a `.mlisp` file and verify:
   - Syntax highlighting works
   - Brackets match
   - Snippets expand with Tab
   - Commands appear in Command Palette

### Debugging

```bash
# Check JavaScript output
cat dist/vscode_mlisp.bc.js | head -50

# Verify exports
grep -o "exports\\.activate" dist/vscode_mlisp.bc.js
```

## Common Issues

### Build fails with "Unbound module"

**Solution:** Make sure opam dependencies are installed:
```bash
opam install . --deps-only
```

### esbuild fails with "vscode not found"

**Solution:** This is expected - `--external:vscode` marks vscode as external

### Extension doesn't activate

**Check:**
- `package.json` has `"activationEvents": ["onStartupFinished"]`
- `main` field points to `./dist/vscode_mlisp.bc.js`
- Extension loads without errors in VSCode

## Publishing

```bash
# Publish to VSCode Marketplace
npm run deploy:vsce

# Or to Open VSIX (alternative marketplace)
npm run deploy:ovsx
```
```

## Architecture Notes

This extension is unique - it's written in OCaml:

```
vscode_mlisp.ml (OCaml)
    ↓ js_of_ocaml
vscode_mlisp.bc.js (JavaScript bytecode)
    ↓ esbuild
dist/vscode_mlisp.bc.js (bundled)
    ↓
VSCode loads extension
```

This allows us to:
- Write type-safe OCaml code
- Potentially embed the MLisp interpreter directly
- Share code with the interpreter package
```

## Adding New Features

### New Commands

1. Add command to `package.json` `contributes.commands`
2. Implement handler in `vscode_mlisp.ml`
3. Export with `Js.export`
4. Test in Extension Development Host

### New Language Features

1. Update `mlisp.tmLanguage.json` in `packages/shared/syntax/`
2. Copy to `packages/vscode-ext/syntaxes/`
3. Rebuild and test
```

**Step 2: Commit**

```bash
git add packages/vscode-ext/DEVELOPMENT.md
git commit -m "docs(vscode-ext): add comprehensive development guide"
```

---

## Task 8: Update Root README with VSCode Extension Section

**Files:**
- Modify: `README.md`

**Step 1: Find VSCode section in README**

Read current README to see where VSCode is mentioned.

**Step 2: Add or update VSCode extension section**

Add after "OCaml Standard Library Bindings" section:

```markdown
## VSCode Extension

MLisp includes a VSCode language extension written entirely in OCaml using js_of_ocaml, providing syntax highlighting and language features.

### Installation

**From VSCode Marketplace:**

1. Open VSCode
2. Search for "MLisp"
3. Click "Install"

**From source:**

```bash
cd packages/vscode-ext
npm run package
code --install-extension mlisp-vscode.vsix
```

### Features

- **Syntax highlighting** for `.mlisp` files
- **Code snippets** for common MLisp constructs
- **Bracket matching** and auto-closing pairs
- **Comments** toggle with `;;`
- **Commands**:
  - `MLisp: Start REPL` - Opens MLisp REPL output channel
  - `MLisp: Evaluate Selection` - Evaluates selected code (Ctrl+Enter)

### Keyboard Shortcuts

| Key | Command |
|-----|----------|
| Ctrl+Enter | MLisp: Evaluate Selection |

### Development

The extension is unique - it's written in OCaml and compiled to JavaScript via `js_of_ocaml`, allowing type-safe access to VSCode APIs. See [packages/vscode-ext/DEVELOPMENT.md](packages/vscode-ext/DEVELOPMENT.md) for contributing.

### Syntax Examples

The extension highlights:

```lisp
;; Comments are italic gray
;; Keywords like if, define, lambda are highlighted
(define factorial (n)
  (if (== n 0)
      1
      (* n (factorial (- n 1)))))

;; Strings are green
"hello world"

;; Booleans #t and #f are highlighted
#t
#f

;; Numbers are highlighted
42
3.14
```

---

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add VSCode extension section to README"
```

---

## Task 9: Final Integration Test

**Files:**
- Test: Full extension workflow

**Step 1: Clean build everything**

Run:
```bash
npm run clean
cd packages/vscode-ext && dune clean && rm -rf dist
cd ..
```

**Step 2: Full rebuild**

Run:
```bash
npm run build:vscode
```

Expected: Extension builds successfully

**Step 3: Bundle extension**

Run:
```bash
npm run bundle:vscode
```

Expected: `dist/vscode_mlisp.bc.js` created

**Step 4: Package extension**

Run:
```bash
npm run package:vscode
```

Expected: `mlisp-vscode.vsix` created

**Step 5: Verify package contents**

Run:
```bash
unzip -l mlisp-vscode.vsix | head -20
```

Expected: Shows extension manifest and bundled JS

**Step 6: Test extension locally**

```bash
code --install-extension mlisp-vscode.vsix
```

Open a `.mlisp` file and verify:
- Syntax highlighting works
- Commands appear in Command Palette (Ctrl+Shift+P)
- Ctrl+Enter executes evaluate selection command

**Step 7: Uninstall**

```bash
code --uninstall-extension mlisp-vscode
rm mlisp-vscode.vsix
```

**Step 8: Verify interpreter still works**

Run:
```bash
npm run build:interpreter
cd packages/interpreter && dune exec mlisp -- -c "(+ 1 2)"
```

Expected: Outputs `3`

**Step 9: Run full test suite**

Run:
```bash
cd packages/interpreter && ./run_tests.sh
```

Expected: All tests pass (42 pass, 2 xfail)

**Step 10: Final summary commit**

```bash
git add -A
git commit --allow-empty -m "feat(vscode-ext): VSCode extension syntax highlighting complete

- Installed js_of_ocaml, gen_js_api and other OCaml dependencies
- Fixed OCaml compilation errors in bindings and extension code
- Successfully bundled extension as JavaScript via js_of_ocaml
- Enhanced TextMate grammar with more patterns (chars, floats, predicates, radix)
- Added code snippets for common MLisp constructs
- Created development guide for extension contributors
- Added VSCode extension section to root README
- Full integration test passed - interpreter and extension work together"
```

---

## Summary of Changes

### Files Created
- `packages/vscode-ext/DEVELOPMENT.md` - Development guide
- `packages/vscode-ext/snippets/mlisp.json` - Code snippets
- `test/syntax_highlighting.mlisp` - Syntax test file

### Files Modified
- `packages/shared/syntax/mlisp.tmLanguage.json` - Enhanced grammar
- `packages/vscode-ext/src-bindings/vscode/vscode.ml` - Fixed compilation errors
- `packages/vscode-ext/src/vscode_mlisp.ml` - Fixed compilation errors
- `packages/vscode-ext/package.json` - Added snippets reference
- `README.md` - Added VSCode extension section

### Dependencies Installed

**OCaml (via opam):**
- js_of_ocaml >= 6.0
- gen_js_api = 1.1.6
- promise_jsoo >= 0.4.3
- jsonoo >= 0.3
- ppxlib >= 0.36
- ocaml-version >= 4.0

**npm (via npm):**
- @biomejs/biome ^1.8.0
- esbuild ^0.20.0
- @vscode/vsce ^2.24.0

### Verification Checklist

- [ ] OCaml dependencies installed
- [ ] npm dependencies installed
- [ ] Extension builds without errors (`dune build`)
- [ ] Extension bundles successfully (`npm run bundle`)
- [ ] Extension packages successfully (`npm run package`)
- [ ] Syntax highlighting works in VSCode
- - Comments highlighted
- - Keywords highlighted
- - Strings, numbers, booleans highlighted
- - Brackets match
- [ ] Snippets expand with Tab
- [ ] Commands appear in Command Palette
- [ ] Ctrl+Enter evaluates selection
- [ ] Interpreter still works independently
- [ ] Full test suite passes

---

## Next Steps (Future Work)

- [ ] Embed MLisp interpreter in VSCode extension for true REPL
- [ ] Add language server protocol (LSP) support
- [ ] Add more editor commands (format, goto definition, etc.)
- [ ] Add debugger integration
- [ ] Publish to VSCode Marketplace
