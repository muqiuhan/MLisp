# PornLisp

<div align=center><img width="150" height="150" src="./res/logo.png"/></div>

<p align="center"> A Lisp dialect implementation in OCaml5 </p>

# Introduction
This project is the MLisp interpreter.

- This project is developed entirely in OCaml 5.0 (Current is OCaml5.0.0~alpha1)

# Demo

- REPL
```lisp
MLisp v0.1.2 (main, Aug 2 2022, 9:52:17) [OCaml 5.0.0~alpha1]

> (env)
- : pair = ((mergesort . #<closure>) (merge . #<closure>) (drop . #<closure>) (take . #<closure>) (length . #<closure>) (null? . #<closure>) (getline . #<closure>) (println . #<closure>) (space .  ) (newline . 
) (cons . #<primitive:pair>) (caddar . #<closure>) (cadar . #<closure>) (caddr . #<closure>) (cadr . #<closure>) (caar . #<closure>) (o . #<closure>) (eval. . #<closure>) (lookup. . #<closure>) (caddar . #<closure>) (cadar . #<closure>) (caddr . #<closure>) (cadr . #<closure>) (caar . #<closure>) (o . #<closure>) (zip. . #<closure>) (list. . #<closure>) (append. . #<closure>) (cons . #<primitive:pair>) (not. . #<closure>) (and. . #<closure>) (null. . #<closure>) (cat . #<primitive:cat>) (int->char . #<primitive:int->char>) (print . #<primitive:print>) (getchar . #<primitive:getchar>) (sym? . #<primitive:sym?>) (atom? . #<primitive:atom?>) (eq . #<primitive:eq>) (cdr . #<primitive:cdr>) (car . #<primitive:car>) (pair . #<primitive:pair>) (list . #<primitive:list>) (<= . #<primitive:<=>) (>= . #<primitive:>=>) (> . #<primitive:>>) (< . #<primitive:<>) (= . #<primitive:=>) (mod . #<primitive:mod>) (/ . #<primitive:/>) (* . #<primitive:*>) (- . #<primitive:->) (+ . #<primitive:+>) (empty-symbol . ))

> (+ 3 5)
- : int = 8

> (and #t #f)
- : boolean = #f

> (and #f #f)
- : boolean = #f

> (or #f #t)
- : boolean = #t

> (or #f #f)
- : boolean = #f

> (if (and #t #f) 3 4)
- : int = 4

> (if (or #t #f) 3 4)
- : int = 3

> (setq x 3)
- : int = 3

> (env)
- : pair = ((x . 3) (mergesort . #<closure>) (merge . #<closure>) (drop . #<closure>) (take . #<closure>) (length . #<closure>) (null? . #<closure>) (getline . #<closure>) (println . #<closure>) (space .  ) (newline . 
) (cons . #<primitive:pair>) (caddar . #<closure>) (cadar . #<closure>) (caddr . #<closure>) (cadr . #<closure>) (caar . #<closure>) (o . #<closure>) (eval. . #<closure>) (lookup. . #<closure>) (caddar . #<closure>) (cadar . #<closure>) (caddr . #<closure>) (cadr . #<closure>) (caar . #<closure>) (o . #<closure>) (zip. . #<closure>) (list. . #<closure>) (append. . #<closure>) (cons . #<primitive:pair>) (not. . #<closure>) (and. . #<closure>) (null. . #<closure>) (cat . #<primitive:cat>) (int->char . #<primitive:int->char>) (print . #<primitive:print>) (getchar . #<primitive:getchar>) (sym? . #<primitive:sym?>) (atom? . #<primitive:atom?>) (eq . #<primitive:eq>) (cdr . #<primitive:cdr>) (car . #<primitive:car>) (pair . #<primitive:pair>) (list . #<primitive:list>) (<= . #<primitive:<=>) (>= . #<primitive:>=>) (> . #<primitive:>>) (< . #<primitive:<>) (= . #<primitive:=>) (mod . #<primitive:mod>) (/ . #<primitive:/>) (* . #<primitive:*>) (- . #<primitive:->) (+ . #<primitive:+>) (empty-symbol . ))

> (+ x 7)
- : int = 10

> (apply pair (list 3 4))
- : pair = (3 . 4)

> (pair 5 6)
- : pair = (5 . 6)

> (setq x (lambda (y) (+ y 1)))
- : closure = #<closure>

> (x 10)
- : int = 11

> (defun x (y) (+ y 1))
- : closure = #<closure>

> (x 10)
- : int = 11

> (defun f (x)
    (if (< x 2)
      1
      (g (- x 1))))
- : closure = #<closure>

> (defun g (x)
    (if (< x 2)
      3
      (f (- x 2))))
- : closure = #<closure>

> (f 10)
- : int = 1

> (g 10)
- : int = 3

> (f (g 10))
- : int = 1

> (let ((x 10)
        (y 20))
    (+ x y))
- : int = 30

> (let* ((x 10)
         (y x))
    (+ x y))
- : int = 20

> (letrec ((f (lambda (x) (g (+ x 1))))
           (g (lambda (x) (+ x 3))))
    (f 0))
- : int = 4

> y

+----------------------------------------------------------------------------
| From : "stdin" , Line: 39 , Column: 0
| | Error: Not found : y
| | Help : Accessing an identifier that has not been defined in the context.
+----------------------------------------------------------------------------
> ())
- : nil = nil

> 
+---------------------------------------------------------------------------------
| From : "stdin" , Line: 39 , Column: 3
| | Error: Syntax error -> Unexcepted character : ')'
| | Help : Usually triggered by wrong characters, such as extra parentheses, etc.
+---------------------------------------------------------------------------------
> 
```

- File
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
