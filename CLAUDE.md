# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MLisp is a Lisp dialect interpreter implemented in OCaml. It features:
- S-expression syntax with prefix notation
- Lexical scoping and closures
- Hygienic macro system with quasiquote/unquote
- Module system for code organization
- REPL for interactive development

## Build and Development Commands

### Building
```bash
# Install dependencies
opam install . --deps-only

# Build the project
dune build

# Build and run binary
dune exec mlisp
```

### Running
```bash
# Start the REPL
dune exec mlisp

# Run a MLisp file
dune exec mlisp -- <file.mlisp>

# Run a specific test file
dune exec mlisp -- test/<test-file>.mlisp
```

**Note**: When executing a file, the interpreter exits with code 1 if any errors occur. The REPL continues on errors.

### Testing
```bash
# Using run_tests.sh (recommended - colored output, detailed errors)
./run_tests.sh                 # Run all tests
./run_tests.sh -v              # Verbose output
./run_tests.sh -s              # Stop on first failure
./run_tests.sh '0[1-5]*.mlisp' # Run specific pattern

# Using Makefile
make test          # Run all tests
make test-verbose  # Run all tests with verbose output
make test-quick    # Run core tests (01-05)
make test-core     # Run core language tests (01-08)
make test-modules  # Run module system tests
make TEST=06_functions test-single  # Run single test

# Using dune directly
dune runtest                   # Run all tests via dune test target
dune exec mlisp -- test/<test-file>.mlisp  # Run a specific test file
```

Tests are `.mlisp` files in the `test/` directory. The test runner (`run_tests.sh`) builds the project, runs each test file, and reports results with colored output.

### Development Workflow

When implementing new language features or modifying the interpreter:

1. **Read language reference** - Consult `README.md` for existing language syntax and semantics
2. **Write tests first** - Add or modify test files in `test/` covering the new functionality
3. **Run test suite** - Execute `./run_tests.sh` to verify all tests pass
4. **Update README.md** - If adding or modifying language features, update the Language Overview and related sections in `README.md`
5. **Check coverage** - Ensure the feature is covered by at least one test case

The test infrastructure detects:
- Non-zero exit codes (runtime errors)
- Error messages in output (`[error]`)
- Assertion failures (`Assertion failed`)
- Warnings (`[warning]`) - allowed for module tests, flagged for others

## Architecture

### Core Pipeline
The interpreter follows this data flow:
```
Input → Lexer → AST → Evaluator → Output
```

### Library Structure
The main `mlisp` library is composed of sub-libraries:
- **mlisp_utils** - Stream wrapper and string utilities
- **mlisp_repl** - REPL implementation with completion and hints
- **mlisp_stdlib** - Standard library loader

### Key Modules

| Directory | Purpose |
|-----------|---------|
| `lib/ast/` | Abstract Syntax Tree construction and parsing |
| `lib/lexer/` | Tokenization and lexical analysis |
| `lib/eval/` | Expression evaluation with quasiquote support |
| `lib/object/` | Core data types (lobject, environments, closures) |
| `lib/macro/` | Macro system with gensym for hygiene |
| `lib/primitives/` | Built-in functions (arithmetic, string, I/O) |
| `lib/stdlib/` | Standard library loader |
| `lib/repl/` | Read-Eval-Print Loop |
| `lib/module_loader/` | Module system implementation |
| `lib/error/` | Error handling and diagnostics (three exception types: `Syntax_error_exn`, `Parse_error_exn`, `Runtime_error_exn`) |
| `lib/print/` | Pretty-printing |
| `lib/utils/` | Utilities (stream handling, string utilities) |

### Entry Points
- `bin/mlisp.ml` - Main executable (REPL and file execution)
- `test/mlisp.ml` - Test runner

### REPL Features
The REPL (`lib/repl/repl.ml`) provides:
- **Tab completion** - Shows available bindings matching current input
- **Inline hints** - Shows type-aware suggestions as you type
- **History** - Persistent history in `.mlisp-repl-history`
- **Multi-line input** - Use `;;` to delimit expressions
- **Error context** - Shows source lines with error location highlighted

## Language Features

**Note**: `README.md` is the canonical reference for MLisp language syntax and semantics. Always consult README.md for the complete language specification before implementing interpreter changes.

### Quasiquote System
MLisp supports full quasiquote with nested quasiquotes:
- `` `expr `` - Quasiquote (literal content)
- `,expr` - Unquote (evaluate and insert)
- `,@expr` - Unquote-splicing (splice list)
- `` ` ``(expr) - Nested quasiquote (use `,,` for unquote at level 2)

The quasiquote implementation in `lib/eval/eval.ml` handles nested quasiquotes by tracking depth levels.

### Macro Hygiene
Macros use `gensym` to generate unique symbols, preventing variable capture. The macro system processes unevaluated S-expressions and returns expanded code for evaluation.

### Module System
Modules provide encapsulation with explicit exports:
```lisp
(module name (export sym1 sym2)
  (define sym1 val1)
  (define sym2 val2))
```

Imports support selective import and aliasing.

## Dependencies

- **OCaml 5.0+** - Implementation language
- **Dune 3.3+** - Build system
- **Core** - Core library (extensions to OCaml stdlib)
- **ocolor, camlp-streams, ocamline, core_unix, ppx_string** - Additional dependencies

See `mlisp.opam` for full dependency list.

## Standard Library

The standard library (`lib/stdlib/stdlib_loader.ml`) is loaded automatically and provides:
- List operations: `null?`, `length`, `append.`, `take`, `drop`, `mergesort`, `zip.`
- Primitives: `cons`, `car`, `cdr`, `list`, `atom?`, `symbol?`
- Core functions: `null.`, `and.`, `not.`, `caar`, `cadr`, etc.
- I/O: `print`, `println`, `getline`, `getchar`
- Type conversion: `int->char`, `symbol-concat`
- Assertions: `assert`

---

## Appendix: OCaml Dune Cheatsheet

Dune is the build system for OCaml projects. This reference covers the essentials for working with Dune in this codebase.

### Project Structure

```
mlisp/
├── dune-project          # Project root metadata (required)
├── dune-workspace        # Optional: build contexts/profiles
├── bin/
│   └── dune              # Executable definitions
├── lib/
│   └── dune              # Library definitions
└── test/
    └── dune              # Test definitions
```

Any directory containing a `dune` file is recognized as a build component.

### The dune-project File

Located at project root, this file defines project metadata:

```lisp
(lang dune 3.3)           # Required: Dune language version
(name mlisp)               # Project identifier
(generate_opam_files true) # Auto-generate .opam files
(source (github user/repo)) # For automatic homepage/bugs in opam
(package
 (name mlisp)
 (version 0.0.44)
 (depends ocaml dune core ocolor camlp-streams ocamline core_unix ppx_string))
```

### Library Stanza

```lisp
(library
 (name mlisp)             # Internal name (used for dependencies)
 (public_name mlisp)      # External name (for opam)
 (libraries core mlisp_utils mlisp_repl)  # Dependencies
 (modules ast lexer eval) # Optional: whitelist of modules
 (wrapped)                # Default: wrap in module namespace
 (preprocess (pps ppx_deriving))  # PPX rewriters
)
```

**Module Wrapping**: By default, `a.ml` and `b.ml` in library `mylib` become `Mylib.A` and `Mylib.B`. Set `(wrapped false)` to disable.

### Executable Stanza

```lisp
(executable
 (name mlisp)             # Entry point: mlisp.ml
 (libraries mlisp)        # Dependencies
 (public_name mlisp)      # Installed binary name
)
```

### Test Stanza

```lisp
(test
 (name mlisp)
 (libraries mlisp))
```

Tests are registered with `@runtest` alias. Use `dune runtest` or `dune test`.

### Common Dune Commands

| Command | Purpose |
|---------|---------|
| `dune build` | Build the project |
| `dune build @all` | Build all targets |
| `dune build @runtest` | Build tests without running |
| `dune runtest` | Run all tests |
| `dune exec mlisp` | Run executable |
| `dune exec mlisp -- file.mlisp` | Pass args to executable |
| `dune clean` | Remove _build directory |
| `dune install` | Install to system |
| `dune promote` | Promote expected test outputs |
| `dune describe` | Show project metadata |
| `dune utop` | Launch REPL with project loaded |

### Build Profiles

Controlled via `--profile` flag or `dune-workspace`:

```lisp
(context
 (default
  (name default)
  (profile dev)))        # or release

(env
 (dev
  (flags (:standard -w -32-41-42-44-45-48-58-60 -warn-error -3)))
 (release
  (flags (:standard -O3))))
```

### Action DSL

For custom build rules:

```lisp
(rule
 (target output.txt)
 (deps input.txt)
 (action
  (with-stdout-to %{target}
    (run %{bin:my_tool} %{deps}))))
```

Built-in actions: `run`, `write-file`, `cat`, `copy`, `diff`, `progn`, `pipe-stdout`, `with-stdout-to`.

### Variables

| Variable | Expansion |
|----------|-----------|
| `%{bin:name}` | Path to binary `name` |
| `%{lib:name}` | Path to library `name` |
| `%{target}` | Current target file |
| `%{deps}` | All dependencies |

### Foreign Stubs (C/C++)

```lisp
(library
 (name mylib)
 (foreign_stubs
  (language c)
  (names stub_a stub_b)
  (flags -I/usr/include/foo)))
```

### Workspace Contexts

For cross-compilation or multiple OCaml versions:

```lisp
(context (opam switch=4.14))
(context (opam switch=5.0))
```

### Reference

- [Dune Documentation](https://dune.readthedocs.io/)
- This project uses Dune 3.3+ (see `dune-project`)
