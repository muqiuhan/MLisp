================================================================================
MLisp Package Manager (mlp)
================================================================================

Package management tool for MLisp. Provides project initialization, dependency
installation, and testing.

Prerequisites
-------------
- OCaml 5.0+
- Interpreter built

Quick Start
-----------
  cd packages/mlp
  dune build

  dune exec mlp -- init xxx     # initialize new project
  dune exec mlp -- install /path # install local package
  dune exec mlp -- test         # run tests

Commands
--------

mlp init [name]
  Create a new MLisp project. Generates:
    my-project/
    ├── package.mlisp     package config
    ├── src/              source files
    ├── test/              tests
    └── modules/           local modules

mlp install <path>
  Install a package from local path
  Installs to ~/.mlisp/packages/

mlp test
  Run all tests in test/ directory
  Requires MLISP_STDLIB_PATH set to stdlib location

Testing Framework
-----------------

Use Rust-style module-test macro to organize tests.

Basic usage:
  (module-test factorial
    (deftest "factorial of 0" (== (factorial 0) 1))
    (deftest "factorial of 5" (== (factorial 5) 120)))

Syntax:
  module-test  groups tests with a name
  deftest     defines a test case

Tests return #t for pass, #f for fail.

Project Structure
----------------
  packages/mlp/
  ├── src/
  │   └── mlp.ml          CLI entry
  ├── lib/
  │   ├── test_runner.ml   test execution
  │   ├── reporter.ml      output formatting
  │   └── installer.ml     package installation
  └── test/
      └── *.mlisp          integration tests

Dependencies
-----------
  ocaml >= 5.0
  dune >= 3.0
  core
  sexplib

FAQ
---

Q: "No test files found"
A: Ensure test/ directory exists with .mlisp files

Q: "Module not found"
A: Module file must exist when using load-module

Q: stdlib not found
A: Set MLISP_STDLIB_PATH environment variable

Documentation
-------------
  Interpreter docs: ../interpreter/README.txt
  Language spec: ../../../docs/language-spec.txt
