<div align="center">

![.github/logo.png](.github/logo.png)

# MLisp

*A Lisp dialect implementation in OCaml*

</div>

![./demo](.github/demo.png)

## Install

1. `opam install . --deps-only`
2. `dune build`
3. `dune install`

## Syntax
```scheme
;; Get all definitions in the current environment
(env)

;; Integer operations
(+ 3 5)
(- 3 5)
(* 3 5)
(/ 3 5)
(mod 3 5)

;; Logical operations
(&& #t #f)
(|| #f #f)
(? (&& #t #f) 3 4)
(> 3 5)
(< 3 5)
(>= 3 5)
(<= 3 5)
(== 3 5)

;; variable definition
(:= x 3)

;; cons
($ 5 6)

;; list
(@ 1 2 3 4 5)

;; apply
(>> $ (@ 3 4))

;; application
(x 10)

;; lambda
(:= x (=> (y) (+ y 1)))

;; function definition
(|= x (y) (+ y 1))

;; let
(%= ((x 10)
     (y 20))
  (+ x y))

;; let*
(%== ((x 10)
      (y x))
  (+ x y))

;; letrec
(=%= ((f (=> (x) (g (+ x 1))))
      (g (=> (x) (+ x 3))))
  (f 0))

;; record
(:= record-x (:: 'x (@ (| 'y 1) (| 'z 2))))

;; record-getter
(:> record-x 'y)
```

## [License](./LICENSE)
This Source Code Form is subject to the terms of the
Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed
with this file, You can obtain one at http://mozilla.org/MPL/2.0/.