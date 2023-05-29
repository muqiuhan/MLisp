let stdlib_string =
  "\n\
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;\n\
   ;; MLisp\t\t\t\t\t\t\t\t    ;;\n\
   ;; Copyright (C) 2022 Muqiu Han\t\t\t\t\t\t    ;;\n\
   ;; \t\t\t\t\t\t\t\t\t    ;;\n\
   ;; This program is free software: you can redistribute it and/or \
   modify\t    ;;\n\
   ;; it under the terms of the GNU Affero General Public License as published \
   ;;\n\
   ;; by the Free Software Foundation, either version 3 of the License, \
   or\t    ;;\n\
   ;; (at your option) any later version.\t\t\t\t\t    ;;\n\
   ;; \t\t\t\t\t\t\t\t\t    ;;\n\
   ;; This program is distributed in the hope that it will be useful,\t    ;;\n\
   ;; but WITHOUT ANY WARRANTY; without even the implied warranty of\t    ;;\n\
   ;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\t    ;;\n\
   ;; GNU Affero General Public License for more details.\t\t\t    ;;\n\
   ;; \t\t\t\t\t\t\t\t\t    ;;\n\
   ;; You should have received a copy of the GNU Affero General Public License \
   ;;\n\
   ;; along with this program.  If not, see <https://www.gnu.org/licenses/>.   \
   ;;\n\
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;\n\n\
   (defun null. (x)\n\
  \  (eq x '()))\n\n\
   (defun and. (x y)\n\
  \  (cond (x (cond (y #t)\n\
  \                 (#t #f)))\n\
  \        (#t #f)))\n\n\
   (defun not. (x)\n\
  \  (cond (x #f)\n\
  \        (#t #t)))\n\n\
   (setq cons pair)\n\n\
   (defun append. (x y)\n\
  \  (cond ((null. x) y)\n\
  \        (#t (cons (car x)\n\
  \                  (append. (cdr x) y)))))\n\n\
   (defun list. (x y)\n\
  \  (cons x (cons y '())))\n\n\
   (defun zip. (x y)\n\
  \  (cond ((and. (null. x) (null. y)) '())\n\
  \        ((and. (not. (atom? x)) (not. (atom? y)))\n\
  \         (cons (list. (car x) (car y))\n\
  \               (zip. (cdr x) (cdr y))))))\n\n\
   (defun o (f g) (lambda (x) (f (g x))))\n\
   (setq caar (o car car))\n\
   (setq cadr (o car cdr))\n\
   (setq caddr (o cadr cdr))\n\
   (setq cadar (o car (o cdr car)))\n\
   (setq caddar (o car (o cdr (o cdr car))))\n\n\n\
   (defun lookup. (key alist)\n\
  \  (cond ((null. alist) 'error)\n\
  \        ((eq (caar alist) key) (cadar alist))\n\
  \        (#t (lookup. key (cdr alist)))))\n\n\
   ; esetq takes two parameters: an expression and an environment. It's like our\n\
   ; evalexp.\n\
   (defun eval. (e env)\n\
  \   (letrec (\n\
  \        ; cond works by evaluating each of the conditions in order until it\n\
  \        ; encounters a truthy one.\n\
  \        (eval-cond. (lambda (c a)\n\
  \            ; If we have no more conditions left, there's an error.\n\
  \            (cond ((null. c) 'error)\n\
  \                  ; If the current condition is true, evaluate that branch.\n\
  \                  ((eval. (caar c) a)  (eval. (cadar c) a))\n\
  \                  ; Otherwise, keep going.\n\
  \                  (#t (eval-cond. (cdr c) a)))))\n\n\
  \        ; This is a manually curried form of map. It runs esetq over every\n\
  \        ; element in a list using the given environment.\n\
  \        (map-eval. (lambda (exps env)\n\
  \          (cond ((null. exps) '())\n\
  \                (#t (cons (eval.  (car exps) env)\n\
  \                          (map-eval. (cdr exps) env))))))\n\
  \            )\n\n\
  \      ; There are a lot of cases to consider. This is like our large match\n\
  \      ; expression.\n\
  \      (cond\n\
  \        ; If it's a symbol, look it up. This is different from pg's Lisp in\n\
  \        ; that he *only* has symbols to work with.\n\
  \        ((sym? e) (lookup. e env))\n\
  \        ; If it's some other type of atom, just leave it be. Let it\n\
  \        ; self-evaluate.\n\
  \        ((atom? e) e)\n\
  \        ; If it's a list (the only alternative to being an atom), check if \
   the\n\
  \        ; first item is an atom.\n\
  \        ((atom? (car e))\n\
  \         ; What kind of form is it?\n\
  \         (cond\n\
  \           ; Quote accepts one argument, so just return that argument as an\n\
  \           ; unevaluated expression (note the lack of a recursive call to\n\
  \           ; eval.).\n\
  \           ((eq (car e) 'quote) (cadr e))\n\
  \           ; For atom?, eq, car, cdr, and cons, just evaluate the expression\n\
  \           ; then pass it through to the built-in form.\n\
  \           ((eq (car e) 'atom?) (atom? (eval. (cadr e)  env)))\n\
  \           ((eq (car e) 'eq)    (eq    (eval. (cadr e)  env)\n\
  \                                       (eval. (caddr e) env)))\n\
  \           ((eq (car e) 'car)   (car   (eval. (cadr e)  env)))\n\
  \           ((eq (car e) 'cdr)   (cdr   (eval. (cadr e)  env)))\n\
  \           ((eq (car e) 'cons)  (cons  (eval. (cadr e)  env)\n\
  \                                       (eval. (caddr e) env)))\n\
  \           ; For cond, it's a wee bit tricker. We get to this function a bit\n\
  \           ; later.\n\
  \           ((eq (car e) 'cond)  (eval-cond. (cdr e) env))\n\
  \           ; A bunch of pass-through math operations.\n\
  \           ((eq (car e) '+)     (+ (eval. (cadr e) env)\n\
  \                                   (eval. (caddr e) env)))\n\
  \           ((eq (car e) '*)     (* (eval. (cadr e) env)\n\
  \                                   (eval. (caddr e) env)))\n\
  \           ((eq (car e) '-)     (- (eval. (cadr e) env)\n\
  \                                   (eval. (caddr e) env)))\n\
  \           ((eq (car e) '<)     (< (eval. (cadr e) env)\n\
  \                                   (eval. (caddr e) env)))\n\
  \           ; ...else, try and evaluate the function as a user-defined \
   function,\n\
  \           ; applying it to the arguments.\n\
  \           (#t (eval. (cons (lookup. (car e) env)\n\
  \                            (cdr e))\n\
  \                      env))))\n\
  \        ; If it's a compound expression in which the first element is a\n\
  \        ; label-expression,\n\
  \        ((eq (caar e) 'label)\n\
  \         ; ...evaluate the expression in environment with a new recursive\n\
  \         ; binding.\n\
  \         (eval. (cons (caddar e) (cdr e))\n\
  \                (cons (list. (cadar e) (car e)) env)))\n\
  \        ; If it's a compound expression in which the first element is a\n\
  \        ; lambda-expresison,\n\
  \        ((eq (caar e) 'lambda)\n\
  \         ; ...evaluate the application of the lambda to the given arguments,\n\
  \         ; evaluating them.\n\
  \         (eval. (caddar e)\n\
  \                (append. (zip. (cadar e)\n\
  \                               (map-eval. (cdr e) env))\n\
  \                         env))))))\n\n\
   (defun o (f g) (lambda (x) (f (g x))))\n\
   (setq caar (o car car))\n\
   (setq cadr (o car cdr))\n\
   (setq caddr (o cadr cdr))\n\
   (setq cadar (o car (o cdr car)))\n\
   (setq caddar (o car (o cdr (o cdr car))))\n\n\
   (setq cons pair)\n\n\
   (setq newline (int->char 10))\n\
   (setq space (int->char 32))\n\n\
   ; This is pretty awkward looking because we have no other way to sequence\n\
   ; operations. We have no begin, nothing.\n\
   (defun println (s)\n\
  \  (let ((ok (print s)))\n\
  \    (print newline)))\n\n\
   ; This is less awkward because we actually use ic and c.\n\
   (defun getline ()\n\
  \  (let* ((ic (getchar))\n\
  \         (c (int->char ic)))\n\
  \    (if (or (eq c newline) (eq ic ~1))\n\
  \      empty-symbol\n\
  \      (cat c (getline)))))\n\n\
   (defun null? (xs)\n\
  \  (eq xs '()))\n\n\
   (defun length (ls)\n\
  \  (if (null? ls)\n\
  \    0\n\
  \    (+ 1 (length (cdr ls)))))\n\n\
   (defun take (n ls)\n\
  \  (if (or (< n 1) (null? ls))\n\
  \    '()\n\
  \    (cons (car ls) (take (- n 1) (cdr ls)))))\n\n\
   (defun drop (n ls)\n\
  \  (if (or (< n 1) (null? ls))\n\
  \    ls\n\
  \    (drop (- n 1) (cdr ls))))\n\n\
   (defun merge (xs ys)\n\
  \  (if (null? xs)\n\
  \    ys\n\
  \    (if (null? ys)\n\
  \      xs\n\
  \      (if (< (car xs) (car ys))\n\
  \        (cons (car xs) (merge (cdr xs) ys))\n\
  \        (cons (car ys) (merge xs (cdr ys)))))))\n\n\
   (defun mergesort (ls)\n\
  \  (if (null? ls)\n\
  \    ls\n\
  \    (if (null? (cdr ls))\n\
  \      ls\n\
  \      (let* ((size (length ls))\n\
  \             (half (/ size 2))\n\
  \             (first (take half ls))\n\
  \             (second (drop half ls)))\n\
  \        (merge (mergesort first) (mergesort second))))))\n\n"
