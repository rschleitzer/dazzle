; num6.scm - the signed-64 OVERFLOW PREDICATES that guard the integer
; accumulation of `*` and `+` (style/primitive.cxx:948-957 and the `+` arm at
; 715/829). They are not primitives themselves; they decide whether a product
; or sum stays an EXACT integer or is promoted to double, so they are visible
; only through the exactness of the result -- `1000000000000` if the integer
; path held, `1e+12` if the guard fired.
;
; Why this fixture exists (2026-08-05): the port's mul guard computed its
; bounds from a HEX literal, which defaults to u64, so `a < maxv / b` was an
; unsigned division. With b negative that reads b as a huge positive and
; answers 0, so every negative `a` compared less and the guard claimed an
; overflow that was not there. `(* -1000000 -1000000)` printed `1e+12` where
; the reference prints the exact `1000000000000` -- a silent deviation no
; corpus document reached.
;
; The cases below walk all four sign combinations for `*` and both directions
; for `+`, then the genuine boundaries: products and sums that really DO
; overflow signed 64 must still promote to double, in both directions.
;
; ASCII ONLY, and MARKUP-FREE (see num1.scm).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (p tag v) (out (string-append tag "=" (number->string v))))

(element doc (make sequence

  ; --- the four sign combinations of `*`, small ---
  (p "mul-pp"   (* 2 3))
  (p "mul-pn"   (* 2 -3))
  (p "mul-np"   (* -2 3))
  (p "mul-nn"   (* -2 -3))

  ; --- the same, large enough that a wrong guard shows as a double ---
  (p "mul-pp-big" (* 1000000 1000000))
  (p "mul-pn-big" (* 1000000 -1000000))
  (p "mul-np-big" (* -1000000 1000000))
  (p "mul-nn-big" (* -1000000 -1000000))

  ; --- unit and zero cases (the guard must not fire at all) ---
  (p "mul-nn-one" (* -1 -1))
  (p "mul-n-one"  (* -1 1))
  (p "mul-zero-n" (* 0 -5))
  (p "mul-n-zero" (* -5 0))

  ; --- three-way and repeated accumulation ---
  (p "mul-three"  (* -2 -3 -4))
  (p "mul-four"   (* -2 -3 -4 -5))

  ; --- products that REALLY overflow: these must promote to double ---
  (p "mul-of-pp"  (* 4000000000 4000000000))
  (p "mul-of-nn"  (* -4000000000 -4000000000))
  (p "mul-of-pn"  (* 4000000000 -4000000000))

  ; --- just inside the boundary: still exact ---
  (p "mul-edge-p" (* 3037000499 3037000499))
  (p "mul-edge-n" (* -3037000499 3037000499))

  ; --- `+` in both directions, exact then overflowing ---
  (p "add-pp"     (+ 2 3))
  (p "add-nn"     (+ -2 -3))
  (p "add-pn"     (+ 9000000000000000000 -9000000000000000000))
  (p "add-of-p"   (+ 9000000000000000000 9000000000000000000))
  (p "add-of-n"   (+ -9000000000000000000 -9000000000000000000))

  ; --- subtraction rides the same `+` guard ---
  (p "sub-nn"     (- -9000000000000000000 9000000000000000000))
  (p "sub-small"  (- -2 -3))
))
