; num3.scm - the XXPRIMITIVE `expt` (primitive.h:235), reachable ONLY as
; "UNREGISTERED::OpenJade//Procedure::expt" through external-procedure: the
; identifier `expt` stays bound to the ISO primitive, which num1/num2 pin.
;
; *This fixture exists because the OpenJade variant carries a defect that is
; DETERMINISTIC and therefore part of the contract: primitive.cxx:5042 reads
; its second quantity from argv[0], so in the dimensionless branch the
; exponent IS the base and argv[1] is never even type-checked. The golden is
; minted from the reference binary, so it records that, not an intent.
;
; NOT probed here, deliberately: an exact-integer or length argv[0], where
; the same line leaves the double uninitialized and the reference powers
; stack garbage. That divergence is documented in COMPLETENESS.md.
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
        ((boolean? v) (if v "#t" "#f"))
        (else "?")))
(define (p tag v) (out (string-append tag "=" (show v))))

(define xexpt (external-procedure "UNREGISTERED::OpenJade//Procedure::expt"))
(define isoexpt (external-procedure "ISO/IEC 10179:1996//Procedure::expt"))

(element doc (process-children))

; both spellings resolve, and they are DIFFERENT procedures
(element a (make sequence
  (out (string-append "have-x=" (if (procedure? xexpt) "#t" "#f")))
  (out (string-append "have-iso=" (if (procedure? isoexpt) "#t" "#f")))
  (p "iso-real"  (isoexpt 2.0 3.0))
  (p "iso-exact" (isoexpt 2 10))
  ; base to its own power, twice, so the pattern is unmistakable
  (p "x-2-3"     (xexpt 2.0 3.0))
  (p "x-3-2"     (xexpt 3.0 2.0))
  (p "x-mixed"   (xexpt 2.0 3))))
; argv[1] is never type-checked in the dimensionless branch: no diagnostic
(element b (p "x-badarg2" (xexpt 2.0 "x")))
; argv[0] IS checked, through the same quantityValue call
(element c (p "x-badarg1" (xexpt "x" 2.0)))
; the DIMENSIONED branch reads argv[1] properly and demands an exact integer
(element d (p "x-lenbad"  (xexpt 2pt "x")))
(default (empty-sosofo))
