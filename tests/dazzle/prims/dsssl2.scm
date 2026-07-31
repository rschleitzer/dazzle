; dsssl2.scm - the same probe list as gate1.scm, run WITH -2.
;
; Two facts in one golden, both measured against the reference binary:
;
;  1. The eleven PRIMITIVE2 entries of primitive.h (the whole vector family,
;     eqv?, memv, quantity->string) plus call-with-current-continuation and
;     the string->quantity alias are installed ONLY under -2. Without it they
;     are UNDEFINED VARIABLES, not procedures. dsssl2.scm runs the same names
;     WITH -2 and gets values.
;  2. Seven names this port used to define have no entry in primitive.h at
;     all and are undefined in BOTH modes: assq, memq, char->integer,
;     integer->char, vector-length, process-node and the call/cc
;     abbreviation. They were removed 2026-07-31.
;
; Each name sits in its own element rule so its diagnostic is attributable.
; The rules only NAME the value; that is enough to report it.
;
; ASCII ONLY, and MARKUP-FREE (see num1.scm).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (nm tag v) (out (string-append tag "=" (if (procedure? v) "PROC" "OTHER"))))

(element doc (process-children))
(element p1 (nm "vector?" vector?))
(element p2 (nm "vector" vector))
(element p3 (nm "vector-ref" vector-ref))
(element p4 (nm "vector-set!" vector-set!))
(element p5 (nm "make-vector" make-vector))
(element p6 (nm "vector->list" vector->list))
(element p7 (nm "list->vector" list->vector))
(element p8 (nm "vector-fill!" vector-fill!))
(element p9 (nm "eqv?" eqv?))
(element p10 (nm "memv" memv))
(element p11 (nm "quantity->string" quantity->string))
(element p12 (nm "call-with-current-continuation" call-with-current-continuation))
(element p13 (nm "string->quantity" string->quantity))
(element p14 (nm "assq" assq))
(element p15 (nm "memq" memq))
(element p16 (nm "char->integer" char->integer))
(element p17 (nm "integer->char" integer->char))
(element p18 (nm "vector-length" vector-length))
(element p19 (nm "process-node" process-node))
(element p20 (nm "call/cc" call/cc))
(default (empty-sosofo))
