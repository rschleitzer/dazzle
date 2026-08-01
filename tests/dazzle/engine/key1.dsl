<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; key1 - the SYNTACTIC KEYWORD table (Interpreter::installSyntacticKeys),
; run WITHOUT -2. key2.dsl is the identical stylesheet WITH -2, and the pair
; is the fixture: three of its four probes answer differently there.
;
; *What this pins:
;  - `keys2[]` (Interpreter.cxx:377) is -2-ONLY. Without the flag `begin`
;    and `set!` are UNDEFINED VARIABLES and `or-element` an UNKNOWN TOP
;    LEVEL FORM. This port installed all three unconditionally.
;  - the -2 ALIAS RULE: a key whose name ends in `?` is also bound without
;    the `?`, so `keep-with-previous:` is a valid make keyword under -2 and
;    an error without it.
;  - *`unknown top level form` fires for a head with NO key AND for a key
;    with no top-level meaning (`if` here). Only THREE keys are skipped
;    without a word: declare-reference-value-type, define-page-model and
;    define-column-set-model. This port used to skip EVERY unhandled form
;    silently, which hid the unported declarations instead of reporting
;    them - and the three silent ones were not even installed as keys.
;
; A MARKED SECTION, not a SYSTEM .scm entity: `set!` is fine but the sibling
; fixtures need `<?`-bearing names, and the pair should read the same way.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

(element doc (process-children))

; --- keys2: -2-only ------------------------------------------------------
(element a (out (string-append "begin=" (number->string (begin 1 2)))))
(element b (out (string-append "set=" (number->string (let ((x 1)) (set! x 5))))))
(or-element ("e" "f") (out "or-element-fired"))

; --- the `?` alias, -2-only ----------------------------------------------
(element c (make paragraph keep-with-previous: #t (literal "C")))
; ... while the `?` spelling is always valid
(element d (make paragraph keep-with-previous?: #t (literal "D")))

; --- unknown top level forms ---------------------------------------------
(zzz-unknown 1 2)
; a key that HAS no top-level meaning is the same diagnostic
(if 1 2)
(lambda (x) x)
; ... and exactly these three are skipped in silence
(declare-reference-value-type "x")
(define-page-model pm 1)
(define-column-set-model cm 1)
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
