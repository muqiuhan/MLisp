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
