let _STDLIB_CORE_VERSION_ = "0.2.1"

let _STDLIB_CORE_ =
  {|
(defun null. (x) (== x '()))
(defun and. (x y)
  (cond (x (cond (y #t)
    (#t #f)))
    (#t #f)))

(defun not. (x)
  (cond (x #f)
    (#t #t)))

(defun append. (x y)
  (cond ((null. x) y)
    (#t (cons (car x)
      (append. (cdr x) y)))))

(defun list. (x y) (cons x (cons y '())))
(defun zip. (x y)
  (cond ((and. (null. x) (null. y)) '())
      ((and. (not. (atom? x)) (not. (atom? y)))
       (cons (list. (car x) (car y))
             (zip. (cdr x) (cdr y))))))

(defun o (f g) (lambda (x) (f (g x))))
(define caar (o car car))
(define cadr (o car cdr))
(define caddr (o cadr cdr))
(define cadar (o car (o cdr car)))
(define caddar (o car (o cdr (o cdr car))))
(defun lookup. (key alist)
  (cond ((null. alist) 'error)
    ((== (caar alist) key) (cadar alist))
    (#t (lookup. key (cdr alist)))))

;; esetq takes two parameters: an expression and an environment. It's like our evalexp.
(defun eval. (e env)
 (letrec (
      ; cond works by evaluating each of the conditions in order until it
      ; encounters a truthy one.
      (eval-cond. (lambda (c a)
              ; If we have no more conditions left, there's an error.
          (cond ((null. c) 'error)
                ; If the current condition is true, evaluate that branch.
                ((eval. (caar c) a)  (eval. (cadar c) a))
                ; Otherwise, keep going.
                (#t (eval-cond. (cdr c) a)))))
      ; This is a manually curried form of map. It runs esetq over every
      ; element in a list using the given environment.
      (map-eval. (lambda (exps env)
        (cond ((null. exps) '())
              (#t (cons (eval.  (car exps) env)
                        (map-eval. (cdr exps) env)))))))
    ; There are a lot of cases to consider. This is like our large match expression.
    (cond
      ; If it's a symbol, look it up. This is different from pg's Lisp in
      ; that he *only* has symbols to work with.
      ((sym? e) (lookup. e env))
      ; If it's some other type of atom, just leave it be. Let it
      ; self-evaluate.
      ((atom? e) e)
      ; If it's a list (the only alternative to being an atom), check if the
      ; first item is an atom.
      ((atom? (car e))
      ; What kind of form is it?
       (cond
         ; Quote accepts one argument, so just return that argument as an
         ; unevaluated expression (note the lack of a recursive call to
         ; eval.).
         ((== (car e) 'quote) (cadr e))
          ; For atom?, eq, car, cdr, and cons, just evaluate the expression
          ; then pass it through to the built-in form.
         ((== (car e) 'atom?) (atom? (eval. (cadr e)  env)))
         ((== (car e) 'eq) (== (eval. (cadr e)  env) (eval. (caddr e) env)))
         ((== (car e) 'car)   (car   (eval. (cadr e)  env)))
         ((== (car e) 'cdr)   (cdr   (eval. (cadr e)  env)))
         ((== (car e) 'cons)  (cons  (eval. (cadr e)  env)
                                     (eval. (caddr e) env)))
         ; For cond, it's a wee bit tricker. We get to this function a bit
         ; later.
         ((== (car e) 'cond)  (eval-cond. (cdr e) env))
         ; A bunch of pass-through math operations.
         ((== (car e) '+) (+ (eval. (cadr e) env) (eval. (caddr e) env)))
         ((== (car e) '*) (* (eval. (cadr e) env) (eval. (caddr e) env)))
         ((== (car e) '-) (- (eval. (cadr e) env) (eval. (caddr e) env)))
         ((== (car e) '<) (< (eval. (cadr e) env) (eval. (caddr e) env)))

         ; ...else, try and evaluate the function as a user-defined function,
         ; applying it to the arguments.
         (#t (eval. (cons (lookup. (car e) env) (cdr e)) env))))

      ; If it's a compound expression in which the first element is a
      ; label-expression,
      ((== (caar e) 'label)
        ; ...evaluate the expression in environment with a new recursive
        ; binding.
       (eval. (cons (caddar e) (cdr e)) (cons (list. (cadar e) (car e)) env)))

      ; If it's a compound expression in which the first element is a
      ; lambda-expresison,
      ((== (caar e) 'lambda)
        ; ...evaluate the application of the lambda to the given arguments,
        ; evaluating them.
       (eval. (caddar e) (append. (zip. (cadar e) (map-eval. (cdr e) env)) env))))))
(defun o (f g) (lambda (x) (f (g x))))
   (define caar (o car car))
   (define cadr (o car cdr))
   (define caddr (o cadr cdr))
   (define cadar (o car (o cdr car)))
   (define caddar (o car (o cdr (o cdr car))))
   (define newline (int->char 10))
   (define space (int->char 32))
; This is pretty awkward looking because we have no other way to sequence
; operations. We have no begin, nothing.
(defun println (s)
  (let ((ok (print s)))
    (print newline)))

; This is less awkward because we actually use ic and c.
(defun getline ()
  (let* ((ic (getchar))
         (c (int->char ic)))
    (if (or (== c newline) (== ic -1))
      empty-symbol
      (symbol-concat c (getline)))))

(defun null? (xs) (== xs '()))
(defun length (ls)
  (if (null? ls)
    0
    (+ 1 (length (cdr ls)))))

(defun take (n ls)
  (if (or (< n 1) (null? ls))
    '()
    (cons (car ls) (take (- n 1) (cdr ls)))))
(defun drop (n ls)
  (if (or (< n 1) (null? ls))
    ls
    (drop (- n 1) (cdr ls))))

(defun merge (xs ys)
  (if (null? xs)
    ys
    (if (null? ys)
      xs
      (if (< (car xs) (car ys))
        (cons (car xs) (merge (cdr xs) ys))
        (cons (car ys) (merge xs (cdr ys)))))))

(defun mergesort (ls)
  (if (null? ls)
    ls
    (if (null? (cdr ls))
      ls
      (let* ((size (length ls))
            (half (/ size 2))
            (first (take half ls))
            (second (drop half ls)))
        (merge (mergesort first) (mergesort second))))))
|}
;;
