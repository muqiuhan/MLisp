MLisp Arithmetic Integration Tests
===================================

These tests verify MLisp arithmetic operations via CLI integration tests.
Batch mode is used for reliable pipe-based testing.

Basic Addition
--------------

Two-argument addition:

  $ echo '(+ 1 2)' | dune exec mlisp -- --batch | grep 'int = 3$'
  - : int = 3

Variadic addition:

  $ echo '(+ 1 2 3 4 5)' | dune exec mlisp -- --batch | grep 'int = 15$'
  - : int = 15

Addition with zero:

  $ echo '(+ 42 0)' | dune exec mlisp -- --batch | grep 'int = 42$'
  - : int = 42

Basic Subtraction
-----------------

Two-argument subtraction:

  $ echo '(- 10 5)' | dune exec mlisp -- --batch | grep 'int = 5$'
  - : int = 5

Variadic subtraction:

  $ echo '(- 100 30 20)' | dune exec mlisp -- --batch | grep 'int = 50$'
  - : int = 50

Negation:

  $ echo '(- 42)' | dune exec mlisp -- --batch | grep 'int = -42$'
  - : int = -42

Basic Multiplication
--------------------

Two-argument multiplication:

  $ echo '(* 3 4)' | dune exec mlisp -- --batch | grep 'int = 12$'
  - : int = 12

Variadic multiplication:

  $ echo '(* 2 3 4 5)' | dune exec mlisp -- --batch | grep 'int = 120$'
  - : int = 120

Multiplication with zero:

  $ echo '(* 999 0)' | dune exec mlisp -- --batch | grep 'int = 0$'
  - : int = 0

Multiplication identity:

  $ echo '(* 42 1)' | dune exec mlisp -- --batch | grep 'int = 42$'
  - : int = 42

Basic Division
--------------

Two-argument division:

  $ echo '(/ 10 2)' | dune exec mlisp -- --batch | grep 'int = 5$'
  - : int = 5

Variadic division:

  $ echo '(/ 100 10 2)' | dune exec mlisp -- --batch | grep 'int = 5$'
  - : int = 5

Division by zero:

  $ echo '(/ 10 0)' | dune exec mlisp -- --batch | grep 'int = 0$'
  - : int = 0

Modulo
------

Modulo operation:

  $ echo '(% 10 3)' | dune exec mlisp -- --batch | grep 'int = 1$'
  - : int = 1

  $ echo '(% 17 5)' | dune exec mlisp -- --batch | grep 'int = 2$'
  - : int = 2

Negative Numbers
----------------

Addition with negative:

  $ echo '(+ -5 5)' | dune exec mlisp -- --batch | grep 'int = 0$'
  - : int = 0

Multiplication with negative:

  $ echo '(* -2 5)' | dune exec mlisp -- --batch | grep 'int = -10$'
  - : int = -10

Division with negative:

  $ echo '(/ -20 4)' | dune exec mlisp -- --batch | grep 'int = -5$'
  - : int = -5

Subtraction resulting in negative:

  $ echo '(- 0 42)' | dune exec mlisp -- --batch | grep 'int = -42$'
  - : int = -42

Nested Arithmetic
------------------

Simple nesting:

  $ echo '(+ (* 2 3) (/ 10 2))' | dune exec mlisp -- --batch | grep 'int = 11$'
  - : int = 11

Mixed operations nesting:

  $ echo '(- (* 4 5) (+ 3 2))' | dune exec mlisp -- --batch | grep 'int = 15$'
  - : int = 15

Deep nesting:

  $ echo '(/ (+ 10 20) (- 10 5))' | dune exec mlisp -- --batch | grep 'int = 6$'
  - : int = 6

Very deep nesting:

  $ echo '(+ (* (- 10 2) 3) (/ 20 (+ 1 1)))' | dune exec mlisp -- --batch | grep 'int = 34$'
  - : int = 34

Comparison Operations
---------------------

Equality:

  $ echo '(== 5 5)' | dune exec mlisp -- --batch | grep 'boolean = #t$'
  - : boolean = #t

  $ echo '(== 5 6)' | dune exec mlisp -- --batch | grep 'boolean = #f$'
  - : boolean = #f

Inequality:

  $ echo '(!= 5 6)' | dune exec mlisp -- --batch | grep 'boolean = #t$'
  - : boolean = #t

Less than:

  $ echo '(< 5 10)' | dune exec mlisp -- --batch | grep 'boolean = #t$'
  - : boolean = #t

  $ echo '(< 10 5)' | dune exec mlisp -- --batch | grep 'boolean = #f$'
  - : boolean = #f

Greater than:

  $ echo '(> 10 5)' | dune exec mlisp -- --batch | grep 'boolean = #t$'
  - : boolean = #t

Less than or equal:

  $ echo '(<= 5 10)' | dune exec mlisp -- --batch | grep 'boolean = #t$'
  - : boolean = #t

  $ echo '(<= 10 10)' | dune exec mlisp -- --batch | grep 'boolean = #t$'
  - : boolean = #t

Greater than or equal:

  $ echo '(>= 10 5)' | dune exec mlisp -- --batch | grep 'boolean = #t$'
  - : boolean = #t

Comparison chaining:

  $ echo '(< 1 (+ 2 3))' | dune exec mlisp -- --batch | grep 'boolean = #t$'
  - : boolean = #t

Floating Point Operations
--------------------------

Float addition:

  $ echo '(+ 1.5 2.5)' | dune exec mlisp -- --batch | grep 'float = 4\.$'
  - : float = 4.

Float subtraction:

  $ echo '(- 5.5 2.3)' | dune exec mlisp -- --batch | grep 'float = 3\.2$'
  - : float = 3.2

Float multiplication:

  $ echo '(* 2.0 3.5)' | dune exec mlisp -- --batch | grep 'float = 7\.$'
  - : float = 7.

Float division:

  $ echo '(/ 10.0 4.0)' | dune exec mlisp -- --batch | grep 'float = 2\.5$'
  - : float = 2.5

Variadic float addition:

  $ echo '(+ 1.0 2.0 3.0)' | dune exec mlisp -- --batch | grep 'float = 6\.$'
  - : float = 6.

Mixed int/float operations:

  $ echo '(+ 1 2 3.5 4)' | dune exec mlisp -- --batch | grep 'float = 10\.5$'
  - : float = 10.5

Float negation:

  $ echo '(- 3.14)' | dune exec mlisp -- --batch | grep 'float = -3\.14$'
  - : float = -3.14

Large Numbers
-------------

Large addition:

  $ echo '(+ 1000000 2000000)' | dune exec mlisp -- --batch | grep 'int = 3000000$'
  - : int = 3000000

Large multiplication:

  $ echo '(* 12345 6789)' | dune exec mlisp -- --batch | grep 'int = 83810205$'
  - : int = 83810205
