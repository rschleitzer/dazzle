<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
(root (process-children))
(element doc (process-children))
; AppendInsn::execute -> spliceNotList, twice: the FIRST member spliced and a
; LATER one. ★A splice in TAIL position is a different compile path (the
; reference lowers it as a dotted tail).
(define (n x) (number->string (length x)))
(define bad 7)
(element p (literal (n (quasiquote ("a" (unquote-splicing bad) "b")))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
