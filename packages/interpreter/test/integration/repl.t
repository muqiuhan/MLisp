MLisp REPL Integration Tests
=============================

These tests verify the MLisp REPL behavior using CLI integration tests.
Batch mode is used for reliable pipe-based testing.

Basic Arithmetic
----------------

Simple addition:

  $ echo '(+ 1 2)' | dune exec mlisp -- --batch | grep 'int = 3$'
  - : int = 3

Subtraction:

  $ echo '(- 10 5)' | dune exec mlisp -- --batch | grep 'int = 5$'
  - : int = 5

Multiplication:

  $ echo '(* 3 4)' | dune exec mlisp -- --batch | grep 'int = 12$'
  - : int = 12

Division:

  $ echo '(/ 10 2)' | dune exec mlisp -- --batch | grep 'int = 5$'
  - : int = 5

Variadic arithmetic:

  $ echo '(+ 1 2 3 4 5)' | dune exec mlisp -- --batch | grep 'int = 15$'
  - : int = 15

Nested arithmetic:

  $ echo '(+ (* 2 3) (/ 10 2))' | dune exec mlisp -- --batch | grep 'int = 11$'
  - : int = 11

Variable Definition and Lookup
------------------------------

Define and reference a variable:

  $ echo '(define x 5)' | dune exec mlisp -- --batch | grep 'int = 5$'
  - : int = 5

Function Definition
-------------------

Define a function using lambda:

  $ echo '(define square (lambda (n) (* n n)))' | dune exec mlisp -- --batch | grep 'closure'
  - : closure = #<lambda:(n)>

Call the defined function:

  $ printf '(define square (lambda (n) (* n n)))\n(square 5)' | dune exec mlisp -- --batch | grep 'int = 25$'
  - : int = 25

Define using defun:

  $ echo '(defun triple (n) (* n 3))' | dune exec mlisp -- --batch | grep 'closure'
  - : closure = #<triple:(n)>

List Operations
---------------

Cons operation:

  $ echo '(cons 1 (cons 2 ()))' | dune exec mlisp -- --batch | grep 'pair = (1 2)$'
  - : pair = (1 2)

Car operation:

  $ echo '(car (list 1 2 3))' | dune exec mlisp -- --batch | grep 'int = 1$'
  - : int = 1

Cdr operation:

  $ echo '(cdr (list 1 2 3))' | dune exec mlisp -- --batch | grep 'pair = (2 3)$'
  - : pair = (2 3)

Quote and Quasiquote
--------------------

Simple quote:

  $ echo "'(1 2 3)" | dune exec mlisp -- --batch | grep 'pair = (1 2 3)$'
  - : pair = (1 2 3)

Quasiquote without unquote:

  $ echo '`(1 2 3)' | dune exec mlisp -- --batch | grep 'pair = (1 2 3)$'
  - : pair = (1 2 3)

Quasiquote with unquote:

  $ echo '`(,1 ,2)' | dune exec mlisp -- --batch | grep 'pair = (1 2)$'
  - : pair = (1 2)

Closures
--------

Closure capturing environment:

  $ echo '(define add-n (lambda (n) (lambda (x) (+ x n))))' | dune exec mlisp -- --batch | grep 'closure'
  - : closure = #<lambda:(n)>

Apply closure:

  $ printf '(define add-n (lambda (n) (lambda (x) (+ x n))))\n((add-n 5) 10)' | dune exec mlisp -- --batch | grep 'int = 15$'
  - : int = 15

Let Bindings
------------

Simple let:

  $ echo '(let ((x 10) (y 20)) (+ x y))' | dune exec mlisp -- --batch | grep 'int = 30$'
  - : int = 30

Letrec for recursive functions:

  $ echo '(letrec ((fact (lambda (n) (if (== n 0) 1 (* n (fact (- n 1))))))) (fact 5))' | dune exec mlisp -- --batch | grep 'int = 120$'
  - : int = 120

Error Handling
--------------

Undefined variable produces error output:

  $ echo '(undefined_symbol)' | dune exec mlisp -- --batch 2>&1 | grep -i 'error'
  [error E200]: Not found: undefined_symbol

Syntax error produces blank line after loading messages:

  $ printf '(\n' | dune exec mlisp -- --batch 2>&1
  o- Loading standard library v0.2.2...
  o- Loaded modules: core, list, io, assert, helper_macros, ocaml
  
