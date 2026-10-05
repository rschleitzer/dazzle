<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; diag1 - the RUNTIME error paths that used to set a location and then say
; NOTHING (the 2026-08-08 dazzle-side message audit). Each of the three
; reaches a different arm: VM::apply_shuffle, CheckInitInsn::execute and
; Identifier::computeValue. The OUTPUT is the point: it is byte-identical
; with and without the diagnostics, which is exactly why no gate saw them.
(root (process-children))
(element doc (process-children))

; ApplyPrimitiveObj::shuffle -> notAList, naming "apply", the ORIGINAL
; argument count as the ordinal and the printed offender.
(element p (literal (apply string-append (cons "a" 2))))

; CheckInitInsn::execute -> uninitializedVariableReference with the name.
(define (uninit) (letrec ((pp (lambda () qq)) (qq (pp))) "x"))

; Identifier::computeValue's beingComputed guard -> identifierLoop.
(define zz (+ zz 1))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
