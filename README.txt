# MLisp

A Lisp dialect implemented in OCaml.

[中文版](./README_zh.txt)

## What is this?

A hobby project. The goal is a clean, practical Lisp interpreter without unnecessary complexity.

## Status

Core interpreter: working
- S-expression parsing, lexical scoping, closures
- Macros (quasiquote/unquote, gensym for hygiene)
- Modules
- REPL

Package manager (mlp): basic features done
- Project initialization
- Local package installation
- Test framework (module-test macro)

VSCode extension: basic features
- Syntax highlighting
- Code evaluation

## Structure

```
mlisp/
├── packages/
│   ├── interpreter/      # OCaml interpreter
│   ├── mlp/              # Package manager
│   ├── vscode-ext/       # VSCode extension
│   └── shared/          # Shared resources
├── docs/                 # Documentation
│   └── language-spec.txt
└── example/              # Example project
```

## Quick Start

### Build the interpreter

```bash
cd packages/interpreter
opam install . --deps-only
dune build

# REPL
dune exec mlisp

# Run a file
dune exec mlisp -- file.mlisp
```

### Build the package manager

```bash
cd packages/mlp
dune build

# Run tests
dune exec mlp -- test
```

### Build the VSCode extension

```bash
cd packages/vscode-ext
opam install . --deps-only
npm install
npm run build
npm run package
```

## Documentation

The [language spec](./docs/language-spec.txt) covers:

- Data types
- Expressions and control flow
- Functions and closures
- Variable bindings
- Modules
- Macros
- Standard library
- OCaml bindings

## License

Mozilla Public License 2.0
