; num1.scm - the NUMERIC / TRANSCENDENTAL primitive family
; (primitive.h:50-57 and 195-212), differentially against the reference C++
; dazzle. Value cases only; everything that reports a message lives in num2.
;
; ASCII ONLY, and MARKUP-FREE: the .scm is read as an SGML entity, so a
; typographic dash in a comment is a "non SGML character" error, an ampersand
; name semicolon is an entity reference, and angle brackets open an element.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

; every probe prints tag= then the printed value; the printer distinguishes
; the RESULT TYPE, which is most of what these primitives decide.
(define (show v)
  (cond ((number? v) (string-append (if (exact? v) "i:" "r:") (number->string v)))
        ((string? v) (string-append "s:" v))
        ((boolean? v) (if v "#t" "#f"))
        (else "?")))

(define (p tag v) (out (string-append tag "=" (show v))))

(element doc (make sequence

  ; --- min / max ---------------------------------------------------------
  ; all-exact stays exact; a double that WINS switches the result to
  ; inexact; a losing double at dimension 0 ALSO switches it (the reference
  ; converts the exact accumulator rather than keeping it).
  (p "min-exact"      (min 3 1 2))
  (p "max-exact"      (max 3 1 2))
  (p "min-one"        (min 7))
  (p "max-one"        (max 7))
  (p "min-dbl-wins"   (min 3 1.5 2))
  (p "max-dbl-wins"   (max 3 4.5 2))
  (p "min-dbl-loses"  (min 1 2.5))
  (p "max-dbl-loses"  (max 9 2.5))
  (p "min-first-dbl"  (min 1.5 3 2))
  (p "max-first-dbl"  (max 1.5 3 2))
  (p "min-neg"        (min -3 -1))
  (p "max-neg"        (max -3 -1))

  ; --- floor / ceiling / truncate / round --------------------------------
  ; an exact integer comes back UNCHANGED (same object, still exact);
  ; an inexact value stays inexact even when it lands on an integer.
  (p "floor-pos"      (floor 2.7))
  (p "floor-neg"      (floor -2.7))
  (p "floor-exact"    (floor 5))
  (p "ceil-pos"       (ceiling 2.3))
  (p "ceil-neg"       (ceiling -2.3))
  (p "ceil-exact"     (ceiling 5))
  (p "trunc-pos"      (truncate 2.7))
  (p "trunc-neg"      (truncate -2.7))
  (p "trunc-exact"    (truncate 5))
  (p "round-half-dn"  (round 2.5))
  (p "round-half-up"  (round 3.5))
  (p "round-neg"      (round -2.5))
  (p "round-exact"    (round 5))

  ; --- sqrt --------------------------------------------------------------
  ; an exact argument whose root is exact comes back EXACT; everything else
  ; is a dimension-0 quantity.
  (p "sqrt-exact"     (sqrt 4))
  (p "sqrt-exact0"    (sqrt 0))
  (p "sqrt-inexact"   (sqrt 2))
  (p "sqrt-real"      (sqrt 2.25))

  ; --- exact? / inexact? -------------------------------------------------
  (p "exact-int"      (exact? 3))
  (p "exact-real"     (exact? 3.0))
  (p "inexact-int"    (inexact? 3))
  (p "inexact-real"   (inexact? 3.0))

  ; --- the libm family ---------------------------------------------------
  (p "exp-0"          (exp 0))
  (p "exp-1"          (exp 1))
  (p "log-1"          (log 1))
  (p "log-e"          (log 2.718281828459045))
  (p "sin-0"          (sin 0))
  (p "cos-0"          (cos 0))
  (p "tan-0"          (tan 0))
  (p "asin-1"         (asin 1))
  (p "asin-0"         (asin 0))
  (p "acos-1"         (acos 1))
  (p "acos-0"         (acos 0))
  (p "atan-1"         (atan 1))
  (p "atan-0"         (atan 0))
  (p "atan2-11"       (atan 1 1))
  (p "atan2-neg"      (atan -1 1))
  (p "atan2-zero"     (atan 0 1))

  ; --- expt --------------------------------------------------------------
  ; exact only when BOTH arguments were exact integers.
  (p "expt-exact"     (expt 2 10))
  (p "expt-exact0"    (expt 5 0))
  (p "expt-mixed"     (expt 2 0.5))
  (p "expt-real"      (expt 2.0 3.0))
  (p "expt-neg-exp"   (expt 2 -1))

  ; --- exact->inexact / inexact->exact -----------------------------------
  (p "e2i-int"        (exact->inexact 3))
  (p "e2i-real"       (exact->inexact 3.5))
  (p "i2e-integral"   (inexact->exact 3.0))
  (p "i2e-int"        (inexact->exact 3))
  (p "i2e-neg"        (inexact->exact -4.0))

  ; --- composition, so an exactness slip shows up twice ------------------
  (p "comp-1"         (+ (floor 2.7) (ceiling 2.3)))
  (p "comp-2"         (* (sqrt 4) (expt 2 3)))
  (p "comp-3"         (max (sqrt 2) 1))
))
(default (empty-sosofo))
