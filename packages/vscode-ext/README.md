# MLisp Language Support for Visual Studio Code

[![VSCode Marketplace](https://img.shields.io/badge/VSCode-Marketplace-blue)](https://marketplace.visualstudio.com/)
[![License](https://img.shields.io/badge/license-MPL--2.0-orange)](LICENSE)

A VSCode extension for MLisp, a Lisp dialect implemented in OCaml. This extension provides syntax highlighting, REPL integration, and code evaluation support for `.mlisp` files.

## Features

### Syntax Highlighting
- Full syntax highlighting for MLisp S-expressions
- Keyword highlighting (`if`, `cond`, `define`, `lambda`, etc.)
- Boolean literals (`#t`, `#f`)
- Numbers (integers and floats)
- Strings with escape sequence support
- Comments (`;;` for line comments, `;|...|;` for block comments)
- Quasiquoting support (`` ` ``, `,`, `,@``)

### REPL Integration
- **Start REPL** command opens an integrated REPL output channel
- Evaluate code directly from the editor
- View results inline or in the output panel

### Code Evaluation
- **Evaluate Selection** (`Ctrl+Enter`) - Execute selected code and see results
- Support for multi-line expressions
- Error reporting with source location

### Editor Support
- Bracket matching for parentheses, brackets, and braces
- Auto-closing pairs for balanced S-expressions
- Comment toggling
- Code folding with region markers

## Installation

### From VSCode Marketplace (Coming Soon)

1. Open VSCode
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "MLisp"
4. Click Install

### From Source

```bash
# Clone the repository
git clone https://github.com/somhairle/mlisp.git
cd mlisp/packages/vscode-ext

# Install dependencies
npm install
opam install . --deps-only

# Build and package
npm run build
npm run package

# Install locally
code --install-extension mlisp-vscode.vsix
```

## Usage

### Opening the REPL

1. Open a `.mlisp` file or create a new one
2. Open the Command Palette (Ctrl+Shift+P)
3. Type "MLisp: Start REPL"
4. The REPL output channel will appear

### Evaluating Code

**Evaluate Selection:**
1. Select code in your editor
2. Press `Ctrl+Enter` (or use Command Palette: "MLisp: Evaluate Selection")
3. Results appear in the output panel

**Example:**
```lisp
;; Select this code and press Ctrl+Enter
(define factorial (n)
  (if (== n 0)
      1
      (* n (factorial (- n 1)))))

(factorial 5)
;; Result: 120
```

### Keyboard Shortcuts

| Keybinding | Command |
|------------|---------|
| `Ctrl+Enter` | Evaluate Selection |

## Screenshots

### Syntax Highlighting
```
;; Keywords are highlighted
(define square (n)
  (* n n))

;; Strings get special coloring
(print "Hello, MLisp!")

;; Booleans stand out
#t
#f

;; Quasiquoting is supported
`(1 ,x 3)
```

### REPL Integration
```
MLisp REPL
==========

> (define x 42)
42

> (+ x 10)
52

> (factorial 5)
120
```

## Language Support

### Supported File Extensions
- `.mlisp` - MLisp source files

### Syntax Features
- **Comments:** `;;` for line comments
- **Booleans:** `#t`, `#f`
- **Numbers:** Integers (`42`, `-17`) and floats (`3.14`)
- **Strings:** Double-quoted with escape sequences (`"hello\nworld"`)
- **Keywords:**
  - Control: `if`, `cond`, `else`, `begin`
  - Definition: `define`, `defun`, `defmacro`, `let`, `let*`, `letrec`
  - Functions: `lambda`, `ocall`
  - Modules: `module`, `import`, `export`
  - Quotes: `quote`, `quasiquote`, `unquote`, `unquote-splicing`
  - Special: `&rest`, `set!`, `setq`

## Requirements

- VSCode 1.80.0 or later
- (Optional) MLisp interpreter for full REPL functionality

## Development

### Building the Extension

This extension is unique - it's written entirely in OCaml and compiled to JavaScript via `js_of_ocaml`:

```bash
# Install OCaml dependencies
opam install . --deps-only

# Install npm dependencies
npm install

# Build OCaml to JavaScript
dune build

# Bundle for VSCode
npm run bundle

# Package as .vsix
npm run package
```

### Project Structure

```
packages/vscode-ext/
├── src/                      # Extension source (OCaml)
│   ├── vscode_mlisp.ml       # Main entry point
│   └── dune                  # Build configuration
├── src-bindings/             # VSCode API bindings
│   └── vscode/
│       ├── vscode.ml         # API implementations
│       ├── vscode.mli        # API signatures
│       └── vscode_stub.js    # JavaScript stub
├── syntaxes/                 # TextMate grammar
│   └── mlisp.tmLanguage.json
├── dist/                     # Bundled output
│   └── vscode_mlisp.bc.js
├── package.json              # Extension manifest
└── dune-project              # OCaml project config
```

### Architecture

```
OCaml Source (vscode_mlisp.ml)
    ↓ js_of_ocaml
JavaScript Bytecode (.bc.js)
    ↓ esbuild
Bundled Extension (dist/)
    ↓ VSCode Extension Host
Loaded Extension
```

This architecture allows:
- Type-safe OCaml development
- Potential to embed the MLisp interpreter directly
- Code sharing with the core interpreter

### Testing

```bash
# Open the Extension Development Host
code --extensionDevelopmentPath=$PWD

# Or press F5 in VSCode with this project open
```

## Contributing

Contributions are welcome! Please see [DEVELOPMENT.md](DEVELOPMENT.md) for detailed guidelines.

### Quick Start for Contributors

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Development Workflow

```bash
# Watch mode for development
npm run dev

# Run linter
npm run check

# Fix formatting
npm run fix
```

## Known Issues

- REPL evaluation requires the MLisp interpreter to be installed separately
- Some advanced language features may not have full syntax highlighting
- Auto-completion is currently limited

## Roadmap

- [ ] Embedded MLisp interpreter (no external dependency)
- [ ] Full language server protocol support
- [ ] Diagnostics and error checking
- [ ] Go to definition
- [ ] Auto-completion for standard library
- [ ] Code formatting
- [ ] Debugging support

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

This extension is licensed under the Mozilla Public License, Version 2.0. See [LICENSE](LICENSE) for details.

## Links

- [MLisp Repository](https://github.com/somhairle/mlisp)
- [MLisp Documentation](../../README.md)
- [Issue Tracker](https://github.com/somhairle/mlisp/issues)
- [VSCode Extension API](https://code.visualstudio.com/api)

## Publisher Information

- **Publisher:** mlisp
- **Extension ID:** mlisp-vscode
- **Repository:** https://github.com/somhairle/mlisp

---

Enjoy coding in MLisp!
