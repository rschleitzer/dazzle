; list1.scm - the remaining LIST / QUANTITY primitives that are available
; WITHOUT the -2 flag: assoc, map-constructor, quantity? and
; quantity->number. The -2-only half (the whole vector family, eqv?, memv and
; quantity->string) lives in dsssl2.scm, and gate1.scm pins that they are
; undefined variables here.
;
; ASCII ONLY, and MARKUP-FREE (see num1.scm).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (show v)
  (cond ((number? v) (string-append (if (exact? v) "i:" "r:") (number->string v)))
        ((string? v) (string-append "s:" v))
        ((symbol? v) (string-append "y:" (symbol->string v)))
        ((boolean? v) (if v "#t" "#f"))
        ((pair? v) (string-append "(" (show (car v)) " . " (show (cdr v)) ")"))
        (else "?")))
(define (p tag v) (out (string-append tag "=" (show v))))

(define al (list (cons "a" 1) (cons "b" 2) (cons 3 "three")))

(element doc (process-children))

(element a (make sequence
  ; --- assoc: ELObj::equal, not identity, so an equal STRING hits --------
  (p "assoc-str"    (assoc "b" al))
  (p "assoc-num"    (assoc 3 al))
  (p "assoc-miss"   (assoc "zz" al))
  (p "assoc-empty"  (assoc "a" (list)))
  ; --- quantity? : the quantityValue gate, so a LENGTH qualifies where
  ; number? does not ---------------------------------------------------
  (p "q-int"        (quantity? 3))
  (p "q-real"       (quantity? 3.5))
  (p "q-len"        (quantity? 1pt))
  (p "q-area"       (quantity? (* 1pt 1pt)))
  (p "q-string"     (quantity? "x"))
  (p "q-symbol"     (quantity? 'sym))
  (p "q-vs-number"  (list (quantity? 1pt) (number? 1pt)))
  ; --- quantity->number: dimensionless keeps its exactness, dimensioned
  ; is scaled to metres per dimension and turns inexact ------------------
  (p "q2n-int"      (quantity->number 3))
  (p "q2n-real"     (quantity->number 3.5))
  (p "q2n-len"      (quantity->number 1pt))
  (p "q2n-area"     (quantity->number (* 1pt 1pt)))
  (p "q2n-inv"      (quantity->number (/ 1.0 1pt)))))

; --- map-constructor: a ZERO-argument procedure per node, sosofos appended
(element b (map-constructor (lambda () (literal (gi (current-node)) " "))
                            (children (current-node))))
; the arity gate is inverted from node-list-map's: any parameter at all is
; tooManyArgs
(element c (map-constructor (lambda (n) (literal "x")) (children (current-node))))
(element d (map-constructor "not-a-procedure" (children (current-node))))
(element e (map-constructor (lambda () (literal "y")) "not-a-node-list"))
; a body that does not return a sosofo
(element f (map-constructor (lambda () 42) (children (current-node))))
; --- assoc's two error shapes ------------------------------------------
(element g (p "assoc-notalist" (assoc "a" (list 1 2))))
(element h (p "assoc-notlist"  (assoc "a" "x")))
(element i (empty-sosofo))
(default (empty-sosofo))
