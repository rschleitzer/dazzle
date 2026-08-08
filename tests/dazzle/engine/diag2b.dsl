<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
(root (process-children))
(element doc (process-children))
; ContinuationObj::call -> continuationDead. call/cc hands BACK the
; continuation, so by the time it is invoked its extent is long gone.
(define (grab) (call-with-current-continuation (lambda (k) k)))
(element p (literal (number->string ((grab) 5))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
