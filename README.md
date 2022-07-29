# OCamLisp

<div align=center><img width="150" height="150" src="./res/logo.png"/></div>

<p align="center"> OCamLisp is a Lisp implementation in OCaml5 </p>

```lisp
$ dune exec ocamlisp
> (env)
((pair . #<primitive:pair>) (+ . #<primitive:+>) (list . #<primitive:list>))
> (+ 3 5)
8
> (and #t #f)
#f
> (and #f #f)
#f
> (or #f #t)
#t
> (or #f #f)
#f
> (if (and #t #f) 3 4)
4
> (if (or #t #f) 3 4)
3
> (define x 3)
3
> (env)
((x . 3) (pair . #<primitive:pair>) (+ . #<primitive:+>) (list . #<primitive:list>))
> (+ x 7)
10
> (apply pair (list 3 4))
(3 . 4)
> (pair 5 6)
(5 . 6)
> (setq x (lambda (y) (+ y 1)))     
#<closure>
> (x 10)
11
> (defun x (y) (+ y 1))
#<closure>
> (x 10)
11
> Goodbye!
```

# Introduction
This is a Lisp interpreter project implemented using OCaml5, not only that, but we will also provide a standard library.

- This project is developed entirely in OCaml 5.0 (Current is OCaml5.0.0~alpha1)

# Build

## From source
### Dependencies
- Since this project is developed using OCaml5, you need to install the OCaml5 environment. The current latest OCaml5 Release version is OCaml5.0.0~alpha1.You can install this version via `opam update && opam switch create 5.0.0~alpha1 --repositories=default,beta=git+https://github.com/ocaml/ocaml-beta-repository.git` to install this version of OCaml environment.

- This project is built with dune, you can install it with `opam install dune`

- The unit test set for this project is written using alcotest, which currently supports OCaml5.0.0~alpha1 and can be installed via `opam install alcotest`.

### Run Build

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
