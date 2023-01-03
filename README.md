# MLisp

<div align=center><img width="150" height="150" src="./.github/logo.png"/></div>

<p align="center"> A Lisp dialect implementation in OCaml </p>

# Start

## REPL
```lisp
MLisp v0.1.7 (main, 2023-01-03 10:45 AM) [OCaml 5.0.0]

mlisp> (env)
- : pair = ((mergesort . #<mergesort:(ls)>)
 (merge . #<merge:(xs ys)>)
  ...
 (empty-symbol . )
)


mlisp> (+ 3 5)
- : int = 8

mlisp> (and #t #f)
- : boolean = #f

mlisp> (or #f #t)
- : boolean = #t

mlisp> (if (and #t #f) 3 4)
- : int = 4

mlisp> (setq x 3)
- : int = 3

mlisp> (env)
- : pair = ((x . 3)
 (mergesort . #<mergesort:(ls)>)
  ...
 (empty-symbol . )
)

mlisp> (+ x 7)
- : int = 10

mlisp> (apply pair (list 3 4))
- : pair = (3 . 4)

mlisp> (pair 5 6)
- : pair = (5 . 6)

mlisp> (setq x (lambda (y) (+ y 1)))
- : closure = #<lambda:(y)>

mlisp> (x 10)
- : int = 11

mlisp> (defun x (y) (+ y 1))
- : closure = #<x:(y)>

mlisp> (x 10)
- : int = 11

mlisp> (defun f (x)
     |   (if (< x 2) 
     |       1
     |       (f (- x 2))))
- : closure = #<f:(x)>

mlisp> (defun g (x)
     |   (if (< x 2)
     |       3
     |       (f (- x 2))))
- : closure = #<g:(x)>

mlisp> (f 10)
- : int = 1

mlisp> (g 10)
- : int = 1

mlisp> (f (g 10))
- : int = 1

mlisp> (let ((x 10)
     |       (y 20))
     |   (+ x y))
- : int = 30

mlisp> (let* ((x 10)
     |        (y x))
     |   (+ x y))
- : int = 20

mlisp> (letrec ((f (lambda (x) (g (+ x 1))))
     |          (g (lambda (x) (+ x 3)))) 
     |   (f 0))
- : int = 4

mlisp> undef
| From : "stdin" , Line: 1 , Column: 0
| | Error: Not found : undef
| | Help : Accessing an identifier that has not been defined in the context.
```

## File
MLisp supports loading programs from files since version 0.1.2, just pass the MLisp source file as the first argument to mlisp, For example:

__File: 05_mutually_recursive_functions.mlisp__
```lisp
 1 │ (defun f (x)
 2 │   (if (< x 2)
 3 │       1
 4 │       (g (- x 1))))
 5 │ 
 6 │ (defun g (x)
 7 │   (if (< x 2)
 8 │       3
 9 │       (f (- x 2))))
10 │ 
11 │ (println (f 10))
```

```shell
$ mlisp 05_mutually_recursive_functions.mlisp 
1
```

Compared to REPL, the error message of the file will be more colorful, For example:

__File: end_test_errors.mlisp:__
```lisp
 1 │ (println "Please don't be nervous, we are just testing the display of error messages")
 2 │ 
 3 │ (defun f (x)
 4 │   (if (< x 2)
 5 │       1
 6 │       (g (- x 1))))
 7 │ 
 8 │ (defun g (x)
 9 │   (if (< x 2)
10 │       3
11 │       (f (- x 2))))
12 │ 
13 │ (f g)
```

```shell
$ mlisp end_test_errors.mlisp 
"Please don\'t be nervous, we are just testing the display of error messages"

+---------------------------------------------------------------------------------------------------------------------------------------
| From : "end_test_errors.mlisp" , Line: 31 , Column: 5
|------> (f g)
| +----------^
| | Error: Parse error -> Type error : (< int int)
| | Help : Possible type error due to a function call with parameters of a type different from that specified in the function definition.
+---------------------------------------------------------------------------------------------------------------------------------------
```

# Build
1. `opam install . --deps-only`
2. `dune build`
3. `dune install`
  
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
