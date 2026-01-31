<div align="center">

![.github/logo.png](.github/logo.png)

# MLisp

*A Lisp dialect implementation in OCaml*

</div>

![./demo](.github/demo.png)

## Table of Contents

- [Introduction](#introduction)
- [Installation](#installation)
- [Language Overview](#language-overview)
- [Data Types](#data-types)
- [Expressions and Control Flow](#expressions-and-control-flow)
- [Functions and Closures](#functions-and-closures)
- [Variable Bindings](#variable-bindings)
- [Modules](#modules)
- [Macros](#macros)
- [Standard Library](#standard-library)
- [OCaml Standard Library Bindings](#ocaml-standard-library-bindings)
  - [Implementation Architecture](#implementation-architecture)
  - [Creating Custom OCaml Bindings](#creating-custom-ocaml-bindings)
- [Examples](#examples)
- [License](#license)

## Introduction

MLisp is a Lisp dialect implemented in OCaml, featuring a clean syntax, lexical scoping, closures, modules, and a macro system. It provides a REPL (Read-Eval-Print Loop) for interactive development and supports both interactive and file-based execution.

## Installation

### Prerequisites

- OCaml 5.0 or later
- Dune build system
- Core library and dependencies (see `mlisp.opam`)

### Building

```bash
# Clone the repository
git clone <repository-url>
cd mlisp

# Install dependencies
opam install . --deps-only

# Build the project
dune build

# Install globally (optional)
dune install
```

### Running

```bash
# Start the REPL
dune exec mlisp

# Run a MLisp file
dune exec mlisp -- <file.mlisp>
```

## Language Overview

MLisp uses S-expression syntax with prefix notation. All expressions are evaluated in a functional style with lexical scoping.

### Basic Syntax

- **Comments**: Lines starting with `;;` are comments
- **S-expressions**: `(function arg1 arg2 ...)`
- **Quoting**: Use `` ` `` for quoting expressions: `` `foo`` or `(quote foo)`

### Error Messages

MLisp provides clear, actionable error messages to help diagnose issues:

#### Error Types

| Error | Code | Description |
|-------|------|-------------|
| Argument Count | E207 | Wrong number of arguments passed to a function |
| Argument Type | E208 | Argument has wrong type (e.g., string instead of int) |
| Value Error | E209 | Invalid value (e.g., negative index, out of bounds) |

#### Examples

```lisp
;; Argument count error
(String.length)
;; Error: Argument count error: 'String.length'
;;        Expected 1 argument(s), but got 0.

;; Type error
(String.length 123)
;; Error: Argument type error: 'String.length'
;;        Parameter 'string' expects type string.

;; Value error
(String.sub "hello" 10 3)
;; Error: Value error: 'String.sub'
;;        substring out of bounds (string length: 5, requested: 10 + 3)
```

## Data Types

### Numbers

MLisp supports integers and floating-point numbers:

```lisp
42          ;; Integer
-17         ;; Negative integer
3.14        ;; Float
```

### Booleans

```lisp
#t          ;; True
#f          ;; False
```

### Strings

```lisp
"hello"     ;; String literal
"world"     ;; Another string
""          ;; Empty string
(@ "Hello" " " "World")  ;; String concatenation: "Hello World"
```

### Symbols

Symbols are identifiers used for variable names and function names:

```lisp
foo         ;; Symbol (when evaluated)
`foo        ;; Quoted symbol
```

### Lists and Nil

Lists are constructed using cons pairs, and `nil` represents the empty list:

```lisp
nil         ;; Empty list
(cons 1 (cons 2 nil))  ;; List: (1 2)
(list 1 2 3)           ;; List constructor: (1 2 3)
(car '(1 2 3))         ;; 1 (first element)
(cdr '(1 2 3))         ;; (2 3) (rest of list)
(atom? x)              ;; #t if x is an atom, #f if it's a pair
```

### Records

Records provide structured data:

```lisp
(record 'point (list (list 'x 10) (list 'y 20)))
(record-get point-record 'x)  ;; Access field
```

## Expressions and Control Flow

### Arithmetic Operations

All arithmetic operators support variadic arguments:

```lisp
(+ 1 2)           ;; 3
(+ 10 20 30)      ;; 60
(- 10 5)          ;; 5
(- 100 30 20)     ;; 50
(* 3 4)           ;; 12
(* 2 3 4)         ;; 24
(/ 10 2)          ;; 5
(/ 100 10 2)      ;; 5
(% 10 3)          ;; 1 (modulo)
```

### Comparison Operators

```lisp
(== 5 5)          ;; #t (equality)
(!= 5 6)          ;; #t (inequality)
(< 5 10)          ;; #t (less than)
(<= 5 10)         ;; #t (less than or equal)
(> 10 5)          ;; #t (greater than)
(>= 10 5)         ;; #t (greater than or equal)
```

### Conditional Expressions

#### If Expression

```lisp
(if #t 1 2)                    ;; Returns 1
(if #f 1 2)                    ;; Returns 2
(if (> 5 3) "yes" "no")        ;; Returns "yes"
```

#### Cond Expression

```lisp
(cond ((< 5 3) 1)
      ((> 5 3) 2)
      ((== 5 3) 3))            ;; Returns 2
```

#### Logical Operators

```lisp
(and #t #t)                    ;; #t
(and #t #f)                    ;; #f
(or #t #f)                     ;; #t
(or #f #f)                     ;; #f
```

#### Begin Expression

The `begin` form sequences multiple expressions and returns the value of the last one:

```lisp
(begin
  (print "First")
  (print "Second")
  42)                          ;; Returns 42, prints "First" and "Second"
```

#### Quote

Use `quote` or `'` to prevent evaluation:

```lisp
(quote foo)                    ;; Symbol foo (unevaluated)
'foo                          ;; Same as (quote foo)
(quote (1 2 3))              ;; List (1 2 3) (unevaluated)
```

#### Quasiquote

Quasiquote (backtick) allows constructing S-expressions with selective evaluation:

- `` `expr `` - Quasiquote: most content is literal (like quote)
- `,expr` - Unquote: evaluate and insert the value
- `,@expr` - Unquote-splicing: evaluate and splice a list into the surrounding list

```lisp
;; Basic quasiquote behaves like quote
`(1 2 3)                      ;; (1 2 3)

;; Unquote - insert evaluated value
(define x 42)
`(1 ,x 3)                     ;; (1 42 3)

;; Multiple unquotes
(define y 10)
`(,x ,y)                      ;; (42 10)

;; Unquote-splicing - splice a list into the result
(define nums '(2 3 4))
`(1 ,@nums 5)                 ;; (1 2 3 4 5)

;; Nested quasiquotes (comma-comma evaluates at level 2)
`` `(1 ,,x)                   ;; `(1 ,42)
```

Quasiquote is especially useful for writing macros that generate code.

## Functions and Closures

### Lambda Expressions

```lisp
(lambda (x y) (+ x y))         ;; Anonymous function
(define add (lambda (x y) (+ x y)))
(add 5 3)                      ;; 8
```

### Function Definition

The `defun` form provides a convenient way to define named functions:

```lisp
(defun square (n) (* n n))
(square 5)                     ;; 25
```

### Recursive Functions

```lisp
(defun factorial (n)
  (if (== n 0)
      1
      (* n (factorial (- n 1)))))
(factorial 5)                  ;; 120
```

### Closures

MLisp supports lexical scoping and closures:

```lisp
(define make-adder (lambda (n) 
  (lambda (x) (+ x n))))
(define add5 (make-adder 5))
(add5 10)                       ;; 15
```

### Higher-Order Functions

```lisp
(define apply-twice (lambda (f x) (f (f x))))
(defun inc (n) (+ n 1))
(apply-twice inc 5)            ;; 7
```

### Apply

The `apply` function applies a function to a list of arguments:

```lisp
(define nums '(1 2 3 4 5))
(apply + nums)                 ;; 15

(define args '(6 7))
(apply * args)                  ;; 42
```

## Variable Bindings

### Define

Global variable definition:

```lisp
(define x 42)
(define y (+ 5 3))
(define greeting "Hello")
```

### Let Bindings

#### Let

Parallel bindings (evaluated simultaneously):

```lisp
(let ((x 5)
      (y 10))
  (+ x y))                     ;; 15
```

#### Let*

Sequential bindings (evaluated in order):

```lisp
(let* ((x 5)
       (y (* x 2)))
  y)                           ;; 10
```

#### Letrec

Recursive bindings for mutually recursive functions:

```lisp
(letrec ((is-even
          (lambda (n)
            (if (== n 0)
                #t
                (is-odd (- n 1)))))
         (is-odd
          (lambda (n)
            (if (== n 0)
                #f
                (is-even (- n 1))))))
  (is-even 10))                ;; #t
```

## Modules

MLisp provides a module system for code organization and encapsulation.

### Module Definition

```lisp
(module math-constants (export pi e)
  (define pi 3.14159)
  (define e 2.71828))
```

### Import

```lisp
;; Import all exports
(import math-constants)
pi                             ;; 3.14159

;; Selective import
(import arithmetic add subtract)
(add 10 5)                     ;; 15

;; Import with alias
(import string-utils :as str)
```

### Module with Functions

```lisp
(module arithmetic (export add subtract multiply)
  (define add (lambda (x y) (+ x y)))
  (define subtract (lambda (x y) (- x y)))
  (define multiply (lambda (x y) (* x y))))
```

## Macros

MLisp supports macros for metaprogramming and code generation. Macros receive their arguments as unevaluated S-expressions and return S-expressions that are then evaluated.

### Macro Definition

```lisp
(defmacro double (x)
  `(+ ,x ,x))

(define result (double 5))    ;; Expands to (+ 5 5) = 10
```

### Quasiquoted Macros

Using quasiquote makes macros more readable:

```lisp
;; When macro - execute body only if condition is true
(defmacro when (condition body)
  `(if ,condition ,body nil))

(when #t (print "Hello"))      ;; Prints "Hello"
(when #f (print "Hello"))      ;; Does nothing

;; Unless macro - opposite of when
(defmacro unless (condition body)
  `(if (not ,condition) ,body nil))

(unless #f (print "Hi"))       ;; Prints "Hi"
```

### Unquote-splicing in Macros

Use `,@` to splice a list into the generated code:

```lisp
;; Macro that creates a function comparing to multiple values
(defmacro member-of (x)
  `(lambda (y) (or ,@(map (lambda (v) `(== ,y ,v)) x))))

(define is-digit (member-of '(0 1 2 3 4 5 6 7 8 9)))
(is-digit 5)                   ;; #t
(is-digit 42)                  ;; #f
```

### Hygienic Macros with Gensym

Use `gensym` to generate unique symbols and avoid variable capture:

```lisp
;; Generate unique symbols
(gensym)                      ;; => g1
(gensym "temp")               ;; => temp_1
(gensym "temp")               ;; => temp_2

;; Hygienic swap macro using gensym
(defmacro swap (a b)
  (let ((temp (gensym "temp")))
    `(let ((,temp ,a))
       (setq ,a ,b)
       (setq ,b ,temp))))

(define x 10)
(define y 20)
(swap x y)
x                             ;; 20
y                             ;; 10
```

### Variadic Macros with &rest

Macros can accept variable numbers of arguments using the `&rest` parameter. The `&rest` parameter collects any remaining arguments into a list:

```lisp
;; Macro that collects all arguments
(defmacro list-all (&rest args)
  `(quote ,args))

(list-all 1 2 3 4)      ;; (1 2 3 4)

;; Fixed parameters followed by rest parameter
(defmacro with-fixed (first second &rest rest)
  `(quote (,first ,second ,@rest)))

(with-fixed 1 2 3 4)    ;; (1 2 3 4)
(with-fixed 1 2)        ;; (1 2) - rest is empty list
```

The `&rest` parameter must be the last parameter in the parameter list. Any arguments beyond the fixed parameters are packed into a list and bound to the rest parameter name.

This is especially useful for creating generic wrapper macros:

```lisp
;; Generic OCaml function call macro
(defmacro ocall (mod method &rest args)
  `((record-get ,mod (quote ,method)) ,@args))

(ocall String length "hello")      ;; 5
(ocall String concat "hello" " world")  ;; "hello world"
(ocall List length '(1 2 3))       ;; 3
```

### Alternative Style (Without Quasiquote)

For completeness, macros can also be written using `list` and `quote`:

```lisp
;; Same when macro without quasiquote
(defmacro when-alt (condition body)
  (list 'if condition body (quote nil)))
```

However, the quasiquote style is generally preferred for readability.

### Macro Debugging Tools

MLisp provides tools to inspect macro expansion, which are helpful for understanding how macros transform code.

#### `macroexpand-1`

Expand a macro call by a single level, without recursively expanding nested macros:

```lisp
(defmacro square (x)
  `(* ,x ,x))

(defmacro double-square (x)
  `(double (square ,x)))

;; Single-step expansion - only the outer macro is expanded
(macroexpand-1 '(double-square 5))
;; => (double (square 5))
```

#### `macroexpand`

Fully expand all macros recursively until no macro calls remain:

```lisp
;; Full expansion - all macros are expanded
(macroexpand '(double-square 5))
;; => (* (* 5 5) (* 5 5))
```

These tools are invaluable for debugging complex macros that expand to other macros.

### Helper Macros for Hygienic Macro Programming

MLisp provides helper macros that simplify writing hygienic macros that avoid variable capture.

#### `with-gensym`

Generate a unique symbol for a single name:

```lisp
(defmacro make-multiplier (value)
  (with-gensym temp
    `(lambda (x)
       (* x ,value))))
```

#### `with-gensyms2` and `with-gensyms3`

Generate unique symbols for multiple names:

```lisp
(defmacro make-composed (f g)
  (with-gensyms2 x y
    `(lambda (,x)
       (,f (,g ,x)))))
```

For convenience, variants are provided for different arities:
- `with-gensym` - 1 symbol
- `with-gensyms2` - 2 symbols
- `with-gensyms3` - 3 symbols

With `&rest` support, you can also create your own variadic helper macros for more symbols:

#### Example: Avoiding Variable Capture

Helper macros ensure unique temporary variables in macro expansion:

```lisp
(defmacro safe-square (x)
  (with-gensym result
    `(let ((,result (* ,x ,x)))
       ,result)))

;; Expands to code with a unique variable, avoiding capture
```

## Standard Library

MLisp includes a comprehensive standard library loaded automatically.

### List Operations

```lisp
(null? '())                    ;; #t
(length '(1 2 3))              ;; 3
(append. '(1 2) '(3 4))        ;; (1 2 3 4)
(take 2 '(1 2 3 4))           ;; (1 2)
(drop 2 '(1 2 3 4))           ;; (3 4)
(mergesort '(3 1 4 2))        ;; (1 2 3 4)
(zip. '(1 2) '(a b))          ;; ((1 a) (2 b))
(map (lambda (x) (* x 2)) '(1 2 3))  ;; (2 4 6)
(pair? '(1 2))                ;; #t (checks if x is a pair/cons cell)
```

### Core Functions

```lisp
(null. x)                      ;; Check if list is empty
(and. x y)                     ;; Logical AND
(not. x)                       ;; Logical NOT
(caar ls)                      ;; (car (car ls))
(cadr ls)                      ;; (car (cdr ls))
```

### Input/Output

```lisp
(print "Hello")                ;; Print to stdout
(println "Hello")              ;; Print with newline
(getline)                      ;; Read a line from stdin
(getchar)                      ;; Read a character (returns integer)
```

### Type Conversion

```lisp
(int->char 65)                 ;; Convert integer to character symbol
(symbol-concat 'a 'b)          ;; Concatenate two symbols
```

### Assertions

```lisp
(assert (= result 10))         ;; Assert condition
```

## OCaml Standard Library Bindings

MLisp provides bindings to selected OCaml standard library functions through the `String` and `List` modules. These modules are exposed as Record objects accessible via `record-get`.

### Accessing OCaml Module Functions

#### Direct Access (record-get)

```lisp
;; Get a function from a module
((record-get String (quote length)) "hello")  ;; 5

;; Define a helper for repeated use
(define string-length (record-get String (quote length)))
(string-length "world")                          ;; 5
```

#### Using Variadic Macro (ocall)

The `ocall` macro handles any number of arguments:

```lisp
;; Single argument
(ocall String length "hello")      ;; 5

;; Two arguments
(ocall String concat "hello" " world")  ;; "hello world"

;; Three arguments
(ocall String sub "hello" 1 3)     ;; "ell"

;; More arguments as needed
(ocall YourModule your-method arg1 arg2 arg3 arg4 ...)
```

### String Module

The `String` module provides string manipulation functions:

```lisp
;; String.length - get string length
(ocall String length "hello")      ;; 5

;; String.concat - concatenate two strings
(ocall String concat "hello" "world")  ;; "helloworld"

;; String.split - split by separator (single char)
(ocall String split "a,b,c" ",")    ;; ("a" "b" "c")

;; String.upper - convert to uppercase
(ocall String upper "hello")        ;; "HELLO"

;; String.lower - convert to lowercase
(ocall String lower "HELLO")        ;; "hello"

;; String.sub - extract substring
(ocall String sub "hello" 1 3)     ;; "ell" (pos=1, len=3)

;; String.contains? - check if substring exists
(ocall String contains? "hello" "ell")   ;; #t
(ocall String contains? "hello" "xyz")   ;; #f

;; String.trim - strip leading/trailing whitespace
(ocall String trim "  hello  ")     ;; "hello"
```

### List Module

The `List` module provides list manipulation functions:

```lisp
;; List.length - get list length
(ocall List length '(1 2 3))       ;; 3

;; List.append - concatenate two lists
(ocall List append '(1 2) '(3 4))  ;; (1 2 3 4)

;; List.rev - reverse a list
(ocall List rev '(1 2 3))          ;; (3 2 1)

;; List.nth - get element at index
(ocall List nth '(10 20 30) 1)     ;; 20

;; List.mem - check membership
(ocall List mem 2 '(1 2 3))        ;; #t
(ocall List mem 5 '(1 2 3))        ;; #f

;; List.flatten - flatten one level of nesting
(ocall List flatten '((1 2) (3 4))) ;; (1 2 3 4)

;; List.concat - concatenate a list of lists
(ocall List concat '((1 2) (3 4))) ;; (1 2 3 4)

;; List.sort - sort numbers ascending
(ocall List sort '(3 1 4 1 5))     ;; (1 1 3 4 5)
```

### Implementation Architecture

OCaml bindings are implemented in `lib/primitives/ocaml.ml` using the following architecture:

```ocaml
(* 1. Validation helper functions from Mlisp_primitives__Validate *)
let check_arg_count = Mlisp_primitives__Validate.check_arg_count
let require_string = Mlisp_primitives__Validate.require_string
let require_int = Mlisp_primitives__Validate.require_int
let require_list = Mlisp_primitives__Validate.require_list

(* 2. Each binding function validates arguments and returns MLisp objects *)
let string_length args =
  check_arg_count "String.length" args 1;
  let s = require_string "String.length" "string" (List.hd_exn args) in
  Object.Fixnum (String.length s)

(* 3. Modules are created as Record objects containing function bindings *)
let string_module =
  make_module "String"
    [ "length", string_length
    ; "concat", string_concat
    ; ...
    ]

(* 4. All modules are exported via the basis list *)
let basis = [ "String", string_module; "List", list_module ]
```

## Creating Custom OCaml Bindings

This section explains how to add new OCaml standard library bindings to MLisp.

### Step-by-Step Guide

#### Step 1: Write the Binding Function

Add your function to `lib/primitives/ocaml.ml`:

```ocaml
(** String.replace - replaces all occurrences of pattern.
    (String.replace "hello world" "world" "there") -> "hello there" *)
let string_replace args =
  check_arg_count "String.replace" args 3;
  let s = require_string "String.replace" "string" (List.nth_exn args 0) in
  let pattern = require_string "String.replace" "pattern" (List.nth_exn args 1) in
  let replacement = require_string "String.replace" "replacement" (List.nth_exn args 2) in
  Object.String (String.replace_all ~substr:pattern ~with_:replacement s)
;;
```

#### Step 2: Add to Module Definition

Add the function name to the module's binding list:

```ocaml
let string_module =
  make_module "String"
    [ "length", string_length
    ; "concat", string_concat
    ; ...
    ; "replace", string_replace  (* New function *)
    ]
;;
```

#### Step 3: Rebuild

```bash
dune build
```

#### Step 4: Test

```lisp
(ocall String.replace "hello world" "world" "there")
;; => "hello there"
```

### Binding Function Template

```ocaml
(** <Function description>
    (<Module>.<name> <example-args>) -> <return-value> *)
let function_name args =
  (* 1. Validate argument count *)
  check_arg_count "<Module>.<name>" args <expected-count>;

  (* 2. Extract and validate each argument *)
  let arg1 = require_<type> "<Module>.<name>" "<param-name>" (List.nth_exn args 0) in
  let arg2 = require_<type> "<Module>.<name>" "<param-name>" (List.nth_exn args 1) in

  (* 3. Perform OCaml operations *)
  let result = (* OCaml code *) in

  (* 4. Return as MLisp object *)
  Object.<type> result
;;
```

### Validation Helpers

| Function | Purpose |
|----------|---------|
| `check_arg_count name args n` | Validate exact argument count |
| `require_string name param value` | Extract string, raise error if not string |
| `require_int name param value` | Extract integer, raise error if not int |
| `require_list name param value` | Extract list, raise error if not list |
| `check_int_range name param value ~min_value ~max_value` | Validate integer is within range |

### Return Value Constructors

| MLisp Type | OCaml Constructor |
|------------|-------------------|
| String | `Object.String "value"` |
| Integer | `Object.Fixnum (Int.of_int 42)` |
| Float | `Object.Float 3.14` |
| Boolean | `Object.Boolean true` |
| List | `Object.list_to_pair [ocaml_list]` |
| Pair | `Object.Pair (car, cdr)` |

### Example: Adding a New Module

To add a completely new module (e.g., `Array`):

```ocaml
(** Array module bindings *)

(** Array.of-list - creates array from list *)
let array_of_list args =
  check_arg_count "Array.of-list" args 1;
  let lst = require_list "Array.of-list" "list" (List.hd_exn args) in
  let arr = Array.of_list lst in
  Object.Array arr

(** Array.length - returns array length *)
let array_length args =
  check_arg_count "Array.length" args 1;
  (match List.hd_exn args with
   | Object.Array arr -> Object.Fixnum (Array.length arr)
   | _ -> raise (Errors.Runtime_error_exn
                  (Errors.Argument_type_error ("Array.length", "array", "array"))))

(** Create the module *)
let array_module =
  make_module "Array"
    [ "of-list", array_of_list
    ; "length", array_length
    ]

(** Add to basis *)
let basis = [
  "String", string_module;
  "List", list_module;
  "Array", array_module  (* New *)
]
```

After rebuilding, use it in MLisp:

```lisp
(ocall Array.of-list (quote (1 2 3)))
;; => #[1 2 3]

(ocall Array.length #[1 2 3])
;; => 3
```

## Examples

### Factorial

```lisp
(defun factorial (n)
  (if (== n 0)
      1
      (* n (factorial (- n 1)))))

(factorial 5)                  ;; 120
```

### Fibonacci

```lisp
(defun fib (n)
  (if (< n 2)
      n
      (+ (fib (- n 1)) (fib (- n 2)))))

(fib 8)                        ;; 21
```

### Counter Closure

```lisp
(define make-counter (lambda ()
  (let ((count 0))
    (lambda ()
      (define count (+ count 1))
      count))))

(define counter1 (make-counter))
(counter1)                     ;; 1
(counter1)                     ;; 2
(counter1)                     ;; 3
```

### Module Example

```lisp
(module counter-mod (export increment get-count reset)
  (define count 0)
  (define increment (lambda ()
    (define count (+ count 1))
    count))
  (define get-count (lambda () count))
  (define reset (lambda ()
    (define count 0)
    count)))

(import counter-mod)
(increment)                    ;; 1
(increment)                    ;; 2
(get-count)                    ;; 2
(reset)                        ;; 0
```

## License

This Source Code Form is subject to the terms of the
Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed
with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
