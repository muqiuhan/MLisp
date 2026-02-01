# MLisp Interpreter

MLisp is a Lisp dialect interpreter implemented in OCaml, featuring:

- S-expression syntax with prefix notation
- Lexical scoping and closures
- Hygienic macro system with quasiquote/unquote
- Module system for code organization
- Interactive REPL for development

## Prerequisites

You need OCaml 5.0+ and opam installed:

```bash
# Verify OCaml installation
ocaml --version   # Should be 5.0.0 or later
opam --version
```

See [../../README.md](../../README.md) for installation instructions.

## Quick Start

```bash
# From the monorepo root
npm run build:interpreter
npm run test:interpreter

# Or directly in this package
cd packages/interpreter
dune build
./run_tests.sh
```

## Building

### Single Command

```bash
dune build
```

This builds the MLisp binary at `_build/default/bin/mlisp`.

### Build Outputs

| File | Description |
|------|-------------|
| `_build/default/bin/mlisp.exe` | Native binary (faster) |
| `_build/default/bin/mlisp.bc` | Bytecode binary (portable) |

### Clean Build

```bash
dune clean
dune build
```

## Running

### Interactive REPL

```bash
# Using dune
dune exec mlisp

# Or directly
./_build/default/bin/mlisp.exe
```

### Execute a File

```bash
dune exec mlisp -- path/to/file.mlisp
./_build/default/bin/mlisp.exe path/to/file.mlisp
```

### Example Session

```
$ dune exec mlisp
MLisp REPL v0.0.44
Type ';;' to submit, 'Ctrl+D' to exit

> (define factorial (lambda (n)
    (if (== n 0)
        1
        (* n (factorial (- n 1)))))
integer

> (factorial 5)
120

> (define square (lambda (x) (* x x)))
integer

> (square 7)
49

> ,q
```

## Testing

### Run All Tests

```bash
# Using the test script (recommended)
./run_tests.sh

# Or using dune
dune runtest
```

### Test Options

```bash
./run_tests.sh -v          # Verbose output
./run_tests.sh -s          # Stop on first failure
./run_tests.sh '01*.mlisp' # Run specific pattern
```

### Test Files

Tests are `.mlisp` files in the `test/` directory:

| Pattern | Topic |
|---------|-------|
| `01_*.mlisp` | Basic types and literals |
| `02_*.mlisp` | Arithmetic operators |
| `03_*.mlisp` | List operations |
| `04_*.mlisp` | Control flow |
| `05_*.mlisp` | Functions and closures |
| `06_*.mlisp` | Variables and scope |
| `07_*.mlisp` | String operations |
| `08_*.mlisp` | Input/output |
| `09_*.mlisp` | Macros |
| `10_*.mlisp` | Modules |

### Expected Test Results

```
==================================
Test Summary
==================================

  Total tests:    44
  Passed:         42
  Failed:         0
  XFail:          2
  Pass rate:      100%
```

The 2 XFail (expected failures) are tests for known limitations:
- `xfail_circular_dependency` - Circular module dependencies
- `xfail_error_messages` - Error message format tests

## Development

### Project Structure

```
packages/interpreter/
├── bin/
│   └── mlisp.ml          # Main executable entry point
├── lib/
│   ├── ast/              # Abstract Syntax Tree
│   ├── lexer/            # Tokenization
│   ├── eval/             # Expression evaluation
│   ├── object/           # Core data types
│   ├── macro/            # Macro system
│   ├── primitives/       # Built-in functions
│   ├── stdlib/           # Standard library loader
│   ├── repl/             # REPL implementation
│   ├── module_loader/    # Module system
│   ├── error/            # Error handling
│   ├── print/            # Pretty-printing
│   └── utils/            # Utilities
├── test/                 # Test files (.mlisp)
├── run_tests.sh          # Test runner
├── dune-project          # Project metadata
└── README.md             # This file
```

### Sub-libraries

The `mlisp` library is composed of sub-libraries:

| Library | Purpose |
|---------|---------|
| `mlisp_utils` | Stream wrapper, string utilities |
| `mlisp_error` | Error handling (3 exception types) |
| `mlisp_object` | Core data types (lobject, environments) |
| `mlisp_ast` | AST construction and parsing |
| `mlisp_lexer` | Tokenization |
| `mlisp_vars` | Variable management |
| `mlisp_eval` | Expression evaluation |
| `mlisp_macro` | Macro system with gensym |
| `mlisp_primitives` | Built-in functions |
| `mlisp_print` | Pretty-printing |
| `mlisp_stdlib` | Standard library loader |
| `mlisp_repl` | REPL implementation |
| `mlisp_module_loader` | Module system |
| `mlisp_module_cache` | Module caching |

### Adding Features

When implementing new language features:

1. **Read the language reference** - See [../../README.md](../../README.md)
2. **Write tests first** - Add test files to `test/`
3. **Run test suite** - Execute `./run_tests.sh`
4. **Update documentation** - Update README.md if adding syntax
5. **Check coverage** - Ensure feature has test coverage

### Build Commands Reference

```bash
# Build everything
dune build

# Build specific target
dune build bin/mlisp.exe

# Clean build artifacts
dune clean

# Display build profile
dune describe

# Build with verbose output
dune build --verbose
```

## Language Reference

### Special Forms

```lisp
;; Definition
(define name value)
(define (name args) body)

;; Conditionals
(if test then else)
(cond (test1 body1) (test2 body2) (else default))

;; Lambdas
(lambda (args) body)

;; Let bindings
(let ((x 1) (y 2)) body)
(let* ((x 1) (y 2)) body)    ; Sequential
(letrec ((x 1) (y 2)) body)  ; Recursive

;; Quoting
'(1 2 3)           ; Quote
`(1 ,x 3)          ; Quasiquote
`,body             ; Unquote
`,@list            ; Unquote-splicing

;; Modules
(module name (export sym1 sym2)
  (define sym1 val1)
  (define sym2 val2))

(import module-name (sym1 sym2))
(import module-name (sym1 as alias1))
```

### Standard Library Functions

| Function | Description |
|----------|-------------|
| `cons`, `car`, `cdr` | List operations |
| `list`, `append.` | List construction |
| `null?`, `symbol?`, `atom?` | Type predicates |
| `+`, `-`, `*`, `/` | Arithmetic |
| `print`, `println` | Output |
| `getline`, `getchar` | Input |

## Troubleshooting

### Build Errors

**Error: `ocaml: command not found`**
```bash
# Install OCaml via opam
opam switch create 5.0.0
eval $(opam env)
```

**Error: `dune: command not found`**
```bash
opam install dune
```

### Test Failures

If tests fail, check:
1. OCaml version is 5.0+
2. All dependencies are installed: `opam install . --deps-only`
3. Run `dune clean && dune build` first

## Contributing

See [../../README.md](../../README.md) for contribution guidelines.

## License

Mozilla Public License, Version 2.0. See [../../LICENSE](../../LICENSE) for details.

## Links

- [Main Repository](https://github.com/somhairle/mlisp)
- [VSCode Extension](../vscode-ext/)
- [Language Documentation](../../README.md)
