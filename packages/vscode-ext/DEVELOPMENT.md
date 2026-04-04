# VSCode Extension Development Guide

This guide covers developing the MLisp VSCode extension, which is uniquely implemented in OCaml and compiled to JavaScript via `js_of_ocaml`.

## Quick Start

### Prerequisites

- OCaml 5.0+
- opam (OCaml package manager)
- Node.js 18+
- VSCode 1.80.0+

### Initial Setup

```bash
cd packages/vscode-ext

# Install OCaml dependencies
opam install . --deps-only

# Install npm dependencies
npm install

# Build the extension
npm run build
```

## Build Pipeline

### Architecture Overview

The extension follows a unique build pipeline:

```
OCaml Source (.ml files)
    ↓
Dune Build (ocamlopt/jsoo)
    ↓
JavaScript Bytecode (.bc.js)
    ↓
esbuild Bundle
    ↓
dist/vscode_mlisp.bc.js
    ↓
VSCode Extension Host
```

### Build Commands

```bash
# Full build (OCaml + bundle)
npm run build

# OCaml compilation only
npm run build:ocaml

# esbuild bundling only
npm run bundle

# Clean build artifacts
dune clean
rm -rf dist/
```

### Watch Mode

For development with automatic rebuilding:

```bash
# Watch both OCaml and bundling
npm run dev

# Individual watch commands
npm run watch:ocaml   # Dune watch mode
npm run watch:bundle  # esbuild watch mode
```

## Project Structure

```
packages/vscode-ext/
├── src/                          # Extension source code
│   ├── vscode_mlisp.ml           # Main entry point (activate/deactivate)
│   ├── vscode_mlisp.mli          # Type signatures
│   └── dune                      # Build configuration
├── src-bindings/                 # VSCode API bindings (gen_js_api)
│   └── vscode/
│       ├── vscode.ml             # API implementations
│       ├── vscode.mli            # API signatures
│       ├── vscode_stub.js        # JavaScript stub for gen_js_api
│       └── dune                  # Build configuration
├── syntaxes/                     # TextMate grammar
│   └── mlisp.tmLanguage.json     # Syntax highlighting rules
├── dist/                         # Bundled output (generated)
│   └── vscode_mlisp.bc.js        # Final extension bundle
├── package.json                  # VSCode extension manifest
├── language-configuration.json   # Language behavior settings
├── dune-project                  # OCaml project metadata
├── DEVELOPMENT.md                # This file
├── README.md                     # User-facing documentation
├── CHANGELOG.md                  # Version history
└── LICENSE                       # MPL-2.0
```

## Code Organization

### Extension Entry Point (`src/vscode_mlisp.ml`)

The main extension file exports `activate` and `deactivate` functions:

```ocaml
(* Activation function called by VSCode *)
let activate (context : Vscode_bindings.ExtensionContext.t) =
  (* Register commands *)
  (* Set up disposables *)
  Js.undefined

(* Export for VSCode *)
let () =
  Js.export "activate" (Js.wrap_callback activate)

let () =
  Js.export "deactivate" (Js.wrap_callback (fun () -> Js.undefined))
```

### VSCode API Bindings (`src-bindings/vscode/`)

Type-safe OCaml bindings for the VSCode Extension API using `gen_js_api`:

```ocaml
(* Example: Creating an output channel *)
let channel = Window.createOutputChannel ~name:"MLisp REPL"

(* Example: Registering a command *)
let disposable = Commands.registerCommand
  ~command:"mlisp.myCommand"
  ~callback:(fun args -> (* handle command *)) ()
```

## Adding New Features

### Adding a New Command

1. **Update `package.json`:**

```json
"contributes": {
  "commands": [
    {
      "command": "mlisp.myNewCommand",
      "title": "MLisp: My New Command"
    }
  ]
}
```

2. **Implement in `vscode_mlisp.ml`:**

```ocaml
let my_new_command () =
  (* Your implementation here *)
  Js.undefined

(* Register in activate function *)
let cmd = Commands.registerCommand
  ~command:"mlisp.myNewCommand"
  ~callback:(fun _args -> my_new_command ())
  ()
```

3. **Test in Extension Development Host:**

```bash
code --extensionDevelopmentPath=$PWD
```

### Adding Syntax Highlighting

1. Edit `syntaxes/mlisp.tmLanguage.json`
2. Add patterns to the `patterns` array
3. Reload VSCode window (Ctrl+R)

### Adding Keybindings

1. Update `package.json`:

```json
"contributes": {
  "keybindings": [
    {
      "command": "mlisp.myNewCommand",
      "key": "ctrl+shift+m",
      "when": "editorLangId == mlisp"
    }
  ]
}
```

## Testing

### Manual Testing

1. **Launch Extension Development Host:**
   ```bash
   code --extensionDevelopmentPath=$PWD
   ```

2. **Open a `.mlisp` test file** and verify:
   - Syntax highlighting works
   - Commands appear in Command Palette (Ctrl+Shift+P)
   - Keybindings function correctly
   - Output channels display properly

### Test Files

Create test files with various MLisp constructs:

```lisp
;; test_syntax.mlisp
;; Comments
(define x 42)

;; Keywords
(if #t 1 2)
(cond ((> x 0) "positive"))
(lambda (n) (* n n))

;; Strings and booleans
"hello world"
#t
#f

;; Quasiquoting
`(1 ,x 3)
`(1 ,@'(2 3) 4)
```

## Common Issues

### Build Errors

**"Unbound module Vscode_bindings"**

Solution: Make sure dependencies are installed:
```bash
opam install . --deps-only
```

**esbuild fails with "Cannot find module"**

Solution: Build OCaml first:
```bash
dune build
npm run bundle
```

### Runtime Errors

**"Cannot read property of undefined"**

- Check JavaScript console in VSCode (Help > Toggle Developer Tools)
- Verify `gen_js_api` bindings match VSCode API

**Extension doesn't activate**

- Check `activationEvents` in `package.json`
- Verify `main` field points to correct bundled file
- Check VSCode error logs

## Debugging

### VSCode Developer Tools

1. Open VSCode
2. Help > Toggle Developer Tools
3. Check Console tab for errors

### Debugging OCaml Code

Since OCaml is compiled to JavaScript, debugging requires:

1. Add `Js.log` statements for logging:
   ```ocaml
   Js.log "Debug point reached"
   ```

2. Check browser console output

### Inspecting Generated JavaScript

```bash
# View generated JavaScript (before bundling)
cat _build/default/src/vscode_mlisp.bc.js | head -50

# Verify exports
grep -o "exports.activate" dist/vscode_mlisp.bc.js
```

## Code Quality

### Linting

```bash
# Run Biome linter
npm run check

# Auto-fix issues
npm run fix
```

### Type Checking

OCaml provides strong type safety at compile time:
```bash
# Type check without compiling
ocamlc -i src/vscode_mlisp.ml
```

## Packaging

### Creating .vsix Package

```bash
npm run package
```

This creates `mlisp-vscode.vsix` ready for:
- Local installation: `code --install-extension mlisp-vscode.vsix`
- Publishing to VSCode Marketplace

### Publishing to Marketplace

1. Create a publisher account at [marketplace.visualstudio.com](https://marketplace.visualstudio.com)
2. Create a Personal Access Token
3. Login to vsce:
   ```bash
   npx vsce login <publisher-name>
   ```
4. Publish:
   ```bash
   npm run publish
   ```

## Resources

### Documentation
- [VSCode Extension API](https://code.visualstudio.com/api)
- [js_of_ocaml Documentation](https://ocsigen.org/js_of_ocaml/)
- [gen_js_api Documentation](https://ocsigen.org/gen_js_api/)

### Tools
- [vsce (VSCode Extension Manager)](https://github.com/microsoft/vscode-vsce)
- [esbuild (Bundler)](https://esbuild.github.io/)
- [TextMate Grammars](https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide)

### Community
- [MLisp Repository](https://github.com/somhairle/mlisp)
- [Issue Tracker](https://github.com/somhairle/mlisp/issues)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly:
   - Run `npm run build`
   - Test in Extension Development Host
   - Run `npm run check`
5. Submit a pull request

### Code Style

- Follow OCaml naming conventions
- Use descriptive variable names
- Add comments for non-obvious code
- Keep functions small and focused

---

For user-facing documentation, see [README.md](README.md).
