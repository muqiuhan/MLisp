# MLisp

<div align=center><img width="150" height="150" src="./res/logo.png"/></div>

<p align="center"> A Lisp dialect implementation in OCaml5 </p>

# Introduction
This project is the MLisp interpreter.

- This project is developed entirely in OCaml 5.0 (Current is OCaml5.0.0~alpha1)

# Use
See `test/*.mlisp`

# Build

## From source
  Since this project is developed using OCaml5, you need to install the OCaml5 environment. The current latest OCaml5 Release version is OCaml5.0.0~alpha1.You can install this version via `opam update && opam switch create 5.0.0~alpha1 --repositories=default,beta=git+https://github.com/ocaml/ocaml-beta-repository.git` to install this version of OCaml environment.

- This project is built with `dune`, you can install it with `opam install dune`.
- This project relies on [camlp-streams](https://github.com/ocaml/camlp-streams) for `streaming operations`, this library that is usually builtin, if you don't have, you can install it via `opam install camlp-streams`. See details: [https://discuss.ocaml.org/t/module-stream-removed-from-5-0-standard-library](https://discuss.ocaml.org/t/module-stream-removed-from-5-0-standard-library)
- This project relies on [ocolor](https://github.com/marc-chevalier/ocolor) for `error message printing`, you can install it via `opam install ocolor`

1. Build and install with `ocaml pom.ml install`
2. Run all tests via `ocaml pom.ml test`
3. Execute via `mlisp`

NOTE: Uninstall via `ocaml pom.ml uninstall`
  
# License
Copyright (C) 2022 Muqiu Han

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
