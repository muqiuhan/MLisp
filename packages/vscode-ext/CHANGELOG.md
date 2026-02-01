# Changelog

All notable changes to the MLisp VSCode Extension will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Embedded MLisp interpreter for true REPL functionality
- Language Server Protocol (LSP) support
- Diagnostics and error checking
- Go to definition navigation
- Auto-completion for standard library functions
- Code formatting

## [0.1.0] - 2025-02-01

### Added

#### Language Support
- Language registration for `.mlisp` file extension
- Language ID: `mlisp`
- Language configuration with:
  - Bracket pairs: `()`, `[]`, `{}`, `""`
  - Comment toggling with `;;`
  - Folding markers: `;(` ... `;)`

#### Syntax Highlighting
- TextMate grammar for comprehensive syntax highlighting
- Keyword highlighting:
  - Control flow: `if`, `cond`, `else`, `begin`
  - Definitions: `define`, `defun`, `defmacro`, `let`, `let*`, `letrec`, `set!`, `setq`
  - Functions: `lambda`, `ocall`
  - Modules: `module`, `import`, `export`
  - Quoting: `quote`, `quasiquote`, `unquote`, `unquote-splicing`
  - Special: `&rest`
- Literal highlighting:
  - Booleans: `#t`, `#f`
  - Numbers: integers and floats
  - Strings: with escape sequence support
  - Characters: `\#A` format
- Comment highlighting:
  - Line comments: `;;`
  - Block comments: `;|...|;`
- Punctuation highlighting for `()`, `` ` ``, `,`, `'`, `,@`

#### Commands
- `MLisp: Start REPL` - Opens MLisp REPL output channel
- `MLisp: Evaluate Selection` - Evaluates selected code (placeholder)

#### Keybindings
- `Ctrl+Enter` - Evaluate Selection (when in `.mlisp` files)

#### Output Channel
- Dedicated "MLisp REPL" output channel
- Shows evaluation results and REPL output

#### Build System
- OCaml to JavaScript compilation via `js_of_ocaml`
- esbuild bundling for optimized output
- npm scripts for:
  - `build` - Full build
  - `bundle` - Bundle JavaScript
  - `package` - Create `.vsix` file
  - `install:ext` - Install extension locally
  - `dev` - Watch mode for development

### Technical Details

#### Architecture
- Written entirely in OCaml
- Type-safe VSCode API bindings using `gen_js_api`
- Compiled to JavaScript bytecode via `js_of_ocaml`
- Bundled with esbuild (external:vscode)

#### Dependencies
- OCaml 5.0+
- `js_of_ocaml` 6.0+
- `gen_js_api` 1.1.6+
- `promise_jsoo` 0.4.3+
- Node.js 18+
- VSCode 1.80.0+

### Known Issues

- REPL evaluation requires external MLisp interpreter
- `Evaluate Selection` command shows placeholder message
- No diagnostics or error highlighting in editor
- Limited auto-completion
- No go-to-definition support

### Upgrade Notes

This is the initial release of the MLisp VSCode extension.

## [0.0.1] - 2025-01-31

### Added
- Initial extension skeleton
- Basic language registration
- Placeholder VSCode API bindings

---

## Version Conventions

- **Major version** - Incompatible API changes
- **Minor version** - New functionality (backwards compatible)
- **Patch version** - Bug fixes (backwards compatible)

## Release Notes Format

Each release includes:
- Date of release
- New features
- Bug fixes
- Breaking changes (if any)
- Migration guide (if needed)
- Known issues

---

**For more information about MLisp, visit [GitHub](https://github.com/somhairle/mlisp).**
