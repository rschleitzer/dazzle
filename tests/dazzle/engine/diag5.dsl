<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; diag5 - the two COMPILE-time arms.
(root (process-children))
(element doc (process-children))
; CaseExpression::optimize -> caseUnresolvedQuantities: a case datum whose
; unit cannot be resolved is dropped from the dispatch, and the reference
; says so once per case expression rather than narrowing the match silently.
(element p (literal (case 1 ((1foo) "a") (else "b"))))
(define-unit foo (* 2 bar))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
