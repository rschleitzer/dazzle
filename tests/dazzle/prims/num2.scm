; num2.scm - the DIAGNOSTICS and the DIMENSION rules of the numeric
; primitive family. Each probe sits in its OWN element rule because an error
; result unwinds the whole construction rule it appears in, so a single
; sequence would stop at the first one.
;
; ASCII ONLY, and MARKUP-FREE (see num1.scm).
;
; What the golden pins, beyond the message text and the argument ordinal:
;  - which primitives report notAQuantity (the quantityValue gate) and which
;    notANumber (the realValue gate) for the SAME bad argument;
;  - that a LENGTH fails the realValue gate, so floor / atan / expt reject it
;    while min / sqrt / exact? accept it and answer about its dimension;
;  - the two outOfRange domains (a negative or odd-dimensioned sqrt, log at
;    or below zero, the arcs outside -1..1);
;  - incompatibleDimensions across min / max / atan2;
;  - and the one case that reports AND still returns a value:
;    inexact->exact of a non-integral real falls through the C++ case label
;    to `return argv[0]`, so its element prints.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (show v)
  (cond ((number? v) (string-append (if (exact? v) "i:" "r:") (number->string v)))
        ((string? v) (string-append "s:" v))
        ((boolean? v) (if v "#t" "#f"))
        (else "?")))
(define (p tag v) (out (string-append tag "=" (show v))))
; a dimensioned value has no printed form until quantity->string, so it is
; divided back down to a ratio.
(define (pl tag v) (out (string-append tag "=L" (show (/ v 1pt)))))

(element doc (process-children))

; --- the quantityValue gate vs the realValue gate --------------------------
(element minarg   (p "minarg"   (min "x")))
(element minarg2  (p "minarg2"  (min 1 "x")))
(element mindim   (p "mindim"   (min 1pt 2)))
(element maxdim   (p "maxdim"   (max 1 2pt)))
(element flrarg   (p "flrarg"   (floor "x")))
(element flrlen   (p "flrlen"   (floor 1pt)))
(element ceilarg  (p "ceilarg"  (ceiling "x")))
(element trncarg  (p "trncarg"  (truncate "x")))

; --- sqrt: negative, odd dimension, non-quantity --------------------------
(element sqrtneg  (p "sqrtneg"  (sqrt -1)))
(element sqrtodd  (p "sqrtodd"  (sqrt 1pt)))
(element sqrtarg  (p "sqrtarg"  (sqrt "x")))

; --- exactness predicates --------------------------------------------------
(element exarg    (p "exarg"    (exact? "x")))
(element inexarg  (p "inexarg"  (inexact? "x")))

; --- the libm family -------------------------------------------------------
(element exparg   (p "exparg"   (exp "x")))
(element logzero  (p "logzero"  (log 0)))
(element logneg   (p "logneg"   (log -1)))
(element logarg   (p "logarg"   (log "x")))
(element sinarg   (p "sinarg"   (sin "x")))
(element asinhi   (p "asinhi"   (asin 2)))
(element acoslo   (p "acoslo"   (acos -2)))
(element atanarg  (p "atanarg"  (atan "x")))
(element atanlen  (p "atanlen"  (atan 1pt)))
(element atan2arg (p "atan2arg" (atan 1 "x")))
(element atan2dim (p "atan2dim" (atan 1 1pt)))

; --- expt ------------------------------------------------------------------
(element exptarg1 (p "exptarg1" (expt "x" 2)))
(element exptarg2 (p "exptarg2" (expt 2 "x")))
(element exptlen  (p "exptlen"  (expt 1pt 2)))

; --- the exactness conversions --------------------------------------------
(element e2iarg   (p "e2iarg"   (exact->inexact "x")))
(element i2earg   (p "i2earg"   (inexact->exact "x")))
; reports noExactRepresentation and STILL returns its argument
(element i2efrac  (p "i2efrac"  (inexact->exact 3.5)))
(element i2elen   (pl "i2elen"  (inexact->exact 1.5pt)))
(default (empty-sosofo))
