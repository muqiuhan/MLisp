================================================================================
MLisp Interpreter
================================================================================

A Lisp dialect interpreter in OCaml. S-expressions, lexical scoping, closures,
hygienic macros, modules, REPL.

Prerequisites
------------
OCaml 5.0+ and opam

Quick Start
-----------
  cd packages/interpreter
  dune build
  dune exec mlisp               # start REPL
  dune exec mlisp -- file.mlisp  # run file

Build
------
  dune build
  Output: _build/default/bin/mlisp.exe (native) or mlisp.bc (bytecode)

  dune clean && dune build     # clean and rebuild

Testing
-------
  Four-layer test architecture:

  1. Module tests (recommended)
     Uses module-test and deftest macros
     cd packages/mlp && dune exec mlp -- test

  2. Regression tests
     ./run_tests.sh             # run all .mlisp tests
     ./run_tests.sh -v          # verbose output
     ./run_tests.sh -s          # stop on first failure

  3. Unit tests
     dune exec ./test/unit/test_object_runner.exe
     dune exec ./test/unit/test_lexer_runner.exe

  4. Integration tests
     dune test test/integration

  dune runtest                 # run all four layers

Project Structure
----------------
  packages/interpreter/
  ├── bin/
  │   └── mlisp.ml             main entry
  ├── lib/
  │   ├── ast/                 AST
  │   ├── lexer/               lexer
  │   ├── eval/                evaluator
  │   ├── object/              core types
  │   ├── macro/               macros
  │   ├── primitives/          builtins
  │   ├── stdlib/              stdlib loader
  │   ├── repl/                REPL
  │   └── module_loader/       modules
  ├── test/                    test files
  └── stdlib/                  stdlib files

Sub-libraries
-------------
  mlisp_utils       utilities
  mlisp_error       error handling
  mlisp_object      data types
  mlisp_ast         AST
  mlisp_lexer       lexer
  mlisp_eval        evaluator
  mlisp_macro       macros
  mlisp_primitives  builtins
  mlisp_stdlib      stdlib loader
  mlisp_repl        REPL
  mlisp_module_loader modules

FAQ
---
Q: dune: command not found
A: opam install dune

Q: Tests fail
A: Verify OCaml 5.0+, run opam install . --deps-only

Documentation
-------------
  Language spec: ../../../docs/language-spec.txt
