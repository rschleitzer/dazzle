; vec1.scm - the -2-only primitives at WORK (gate1/dsssl2 only pin whether
; the names are bound). Run with -2. The one new implementation here is
; vector-fill!; the rest of the family was already ported and is pinned
; alongside it so the gate change cannot silently break it.
;
; ★NOT probed: the reference's readOnly diagnostic on vector-set! /
; vector-fill!. readOnly is a COLLECTOR bit (Collector.h:20) set by
; makePermanent, and this port has no collector — see COMPLETENESS.md.
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
        ((pair? v) (string-append "(" (show (car v)) " " (show (cdr v)) ")"))
        ((null? v) "()")
        (else "?")))
(define (p tag v) (out (string-append tag "=" (show v))))

(element doc (process-children))

(element a (make sequence
  ; --- vector-fill! : every slot takes argument 2, result unspecified ----
  (p "fill-list"  (let ((v (vector 1 2 3)))
                    (vector-fill! v 'z)
                    (vector->list v)))
  (p "fill-empty" (let ((v (vector)))
                    (vector-fill! v 'z)
                    (vector->list v)))
  (p "fill-made"  (let ((v (make-vector 2 'a)))
                    (vector-fill! v "s")
                    (vector->list v)))
  ; the filled slots are the SAME object, so a mutation through one index is
  ; visible through the others only if the value itself is shared -- here it
  ; is a string, and vector-ref returns it unchanged
  (p "fill-ref"   (let ((v (vector 1 2 3)))
                    (vector-fill! v "q")
                    (vector-ref v 2)))
  ; --- the rest of the family, pinned alongside --------------------------
  (p "vec-list"   (vector->list (vector 1 "b" 'c)))
  (p "list-vec"   (vector->list (list->vector (list 1 2))))
  (p "vec-set"    (let ((v (vector 1 2)))
                    (vector-set! v 0 9)
                    (vector->list v)))
  (p "vec-p"      (vector? (vector)))
  (p "vec-p-no"   (vector? (list)))
  ; --- eqv? / memv --------------------------------------------------------
  (p "eqv-int"    (eqv? 1 1))
  (p "eqv-str"    (eqv? "a" "a"))
  (p "memv-hit"   (memv 2 (list 1 2 3)))
  (p "memv-miss"  (memv 9 (list 1 2 3)))
  ; --- quantity->string: prints what number->string refuses ---------------
  (p "q2s-int"    (quantity->string 3))
  (p "q2s-real"   (quantity->string 3.5))
  (p "q2s-len"    (quantity->string 1pt))
  (p "q2s-area"   (quantity->string (* 1pt 1pt)))
  (p "q2s-radix"  (quantity->string 255 16))
  ; --- string->quantity IS string->number ---------------------------------
  (p "s2q"        (string->quantity "42"))
  (p "s2q-real"   (string->quantity "4.5"))))

; --- the error shapes of the two new gates -------------------------------
(element b (p "fill-notvec"  (vector-fill! (list 1) 'z)))
(element c (p "q2s-notq"     (quantity->string "x")))
(element d (p "q2s-badradix" (quantity->string 255 7)))
(element e (p "q2s-radixarg" (quantity->string 255 "x")))
(default (empty-sosofo))
