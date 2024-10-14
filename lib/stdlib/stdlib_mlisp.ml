let _STDLIB_VERSION_ = "0.2.1"

let _STDLIB_ =
  {|
(|= null. (x) (== x '()))
(|= and. (x y)
  (?? (x (?? (y #t)
    (#t #f)))
    (#t #f)))

(|= not. (x)
  (?? (x #f)
    (#t #t)))

(|= append. (x y)
  (?? ((null. x) y)
    (#t ($ (car x)
      (append. (cdr x) y)))))

(|= list. (x y) ($ x ($ y '())))
(|= zip. (x y)
  (?? ((and. (null. x) (null. y)) '())
      ((and. (not. (atom? x)) (not. (atom? y)))
       ($ (list. (car x) (car y))
             (zip. (cdr x) (cdr y))))))

(|= o (f g) (=> (x) (f (g x))))
(:= caar (o car car))
(:= cadr (o car cdr))
(:= caddr (o cadr cdr))
(:= cadar (o car (o cdr car)))
(:= caddar (o car (o cdr (o cdr car))))
(|= lookup. (key alist)
  (?? ((null. alist) 'error)
    ((== (caar alist) key) (cadar alist))
    (#t (lookup. key (cdr alist)))))

;; esetq takes two parameters: an expression and an environment. It's like our evalexp.
(|= eval. (e env)
 (=%= (
      ; cond works by evaluating each of the conditions in order until it
      ; encounters a truthy one.
      (eval-cond. (=> (c a)
              ; If we have no more conditions left, there's an error.
          (?? ((null. c) 'error)
                ; If the current condition is true, evaluate that branch.
                ((eval. (caar c) a)  (eval. (cadar c) a))
                ; Otherwise, keep going.
                (#t (eval-cond. (cdr c) a)))))
      ; This is a manually curried form of map. It runs esetq over every
      ; element in a list using the given environment.
      (map-eval. (=> (exps env)
        (?? ((null. exps) '())
              (#t ($ (eval.  (car exps) env)
                        (map-eval. (cdr exps) env)))))))
    ; There are a lot of cases to consider. This is like our large match expression.
    (??
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
       (??
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
         ((== (car e) 'cons)  ($  (eval. (cadr e)  env)
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
         (#t (eval. ($ (lookup. (car e) env) (cdr e)) env))))
         
      ; If it's a compound expression in which the first element is a
      ; label-expression,
      ((== (caar e) 'label)
        ; ...evaluate the expression in environment with a new recursive
        ; binding.
       (eval. ($ (caddar e) (cdr e)) ($ (list. (cadar e) (car e)) env)))
      
      ; If it's a compound expression in which the first element is a
      ; lambda-expresison,
      ((== (caar e) 'lambda)
        ; ...evaluate the application of the lambda to the given arguments,
        ; evaluating them.
       (eval. (caddar e) (append. (zip. (cadar e) (map-eval. (cdr e) env)) env))))))
(|= o (f g) (=> (x) (f (g x))))
   (:= caar (o car car))
   (:= cadr (o car cdr))
   (:= caddr (o cadr cdr))
   (:= cadar (o car (o cdr car)))
   (:= caddar (o car (o cdr (o cdr car))))
   (:= newline (int->char 10))
   (:= space (int->char 32))
; This is pretty awkward looking because we have no other way to sequence
; operations. We have no begin, nothing.
(|= println (s)
  (%= ((ok (print s)))
    (print newline)))
    
; This is less awkward because we actually use ic and c.
(|= getline ()
  (%== ((ic (getchar))
         (c (int->char ic)))
    (? (|| (== c newline) (== ic ~1))
      empty-symbol
      (cat c (getline)))))

(|= null? (xs) (== xs '()))
(|= length (ls)
  (? (null? ls)
    0
    (+ 1 (length (cdr ls)))))

(|= take (n ls)
  (? (|| (< n 1) (null? ls))
    '()
    ($ (car ls) (take (- n 1) (cdr ls)))))
(|= drop (n ls)
  (? (|| (< n 1) (null? ls))
    ls
    (drop (- n 1) (cdr ls))))

(|= merge (xs ys)
  (? (null? xs)
    ys
    (? (null? ys)
      xs
      (? (< (car xs) (car ys))
        ($ (car xs) (merge (cdr xs) ys))
        ($ (car ys) (merge xs (cdr ys)))))))

(|= mergesort (ls)
  (? (null? ls)
    ls
    (? (null? (cdr ls))
      ls
      (%== ((size (length ls))
            (half (/ size 2))
            (first (take half ls))
            (second (drop half ls)))
        (merge (mergesort first) (mergesort second))))))
|}
;;
