# OCamLisp

<div align=center><img width="150" height="150" src="./res/logo.png"/></div>

<p align="center"> OCamLisp is a Lisp implementation in OCaml5 </p>

# Introduction
This is a Lisp interpreter project implemented using OCaml5, not only that, but we will also provide a standard library.

- This project is developed entirely in OCaml 5.0 (Current is OCaml5.0.0~alpha1)

__Please note that this is a learning project and should not be used in a production environment!!!__

# Build

# From source
## Dependencies
- Since this project is developed using OCaml5, you need to install the OCaml5 environment. The current latest OCaml5 Release version is OCaml5.0.0~alpha1.You can install this version via `opam update && opam switch create 5.0.0~alpha1 --repositories=default,beta=git+https://github.com/ocaml/ocaml-beta-repository.git` to install this version of OCaml environment.

- This project is built with dune, you can install it with `opam install dune`

- The unit test set for this project is written using alcotest, which currently supports OCaml5.0.0~alpha1 and can be installed via `opam install alcotest`.

## Run Build

- Run `dune build` to build from source
- Run `dune test` to run all test cases
- Run `dune exec ocamlisp` to run the executable

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
