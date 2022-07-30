# MLisp

<div align=center><img width="150" height="150" src="./res/logo.png"/></div>

<p align="center"> A Lisp dialect implementation in OCaml5 </p>

# Introduction
This project is the MLisp interpreter.

- This project is developed entirely in OCaml 5.0 (Current is OCaml5.0.0~alpha1)

# Use
- REPL
```lisp
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
> (defun f (x)
    (if (< x 2)
      1
      (g (- x 1))))
#<closure>
> (defun g (x)
    (if (< x 2)
      3
      (f (- x 2))))
#<closure>
> (f 10)
1
> (g 10)
3
> (let ((x 10)
        (y 20))
    (+ x y))
30
> (let* ((x 10)
         (y x))
    (+ x y))
20
> (letrec ((f (lambda (x) (g (+ x 1))))
           (g (lambda (x) (+ x 3))))                                                                       
    (f 0))
4
> Goodbye!
```

- Meta-circular
```lisp
(eval. '((label fact
                (lambda (x)
                  (cond ((< x 2) 1)
                        (#t (* x (fact (- x 1)))))))
         5)
       '())
```

Since the loading mechanism is not currently implemented, it can be called in the following way:
```shell
./_build/default/bin/main.exe < bin/metacircular.mlisp
```

Or running with OCaml VM:
```shell
./_build/default/bin/main.bc < bin/metacircular.mlisp
```

Result:
```shell
> #<closure>
> #<closure>
> #<closure>
> #<primitive:pair>
> #<closure>
> #<closure>
> #<closure>
> #<closure>
> #<closure>
> #<closure>
> #<closure>
> #<closure>
> #<closure>
> #<closure>
> #<closure>
> #<closure>
> #<closure>
> 120
> Goodbye!
```

# Build

- From source
  Since this project is developed using OCaml5, you need to install the OCaml5 environment. The current latest OCaml5 Release version is OCaml5.0.0~alpha1.You can install this version via `opam update && opam switch create 5.0.0~alpha1 --repositories=default,beta=git+https://github.com/ocaml/ocaml-beta-repository.git` to install this version of OCaml environment.

- Dependencies
  This project is built with dune, you can install it with `opam install dune`
  
- Build
  Run `dune build --profile release` to build release version from source (or `dune build --profile dev` for dev)

- Test
  Run `dune test` to run all test cases

- Exec
  Run `dune exec mlisp` to run the executable

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
