<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
(root (process-children))
; SchemeParser::parseCase -> caseElse: a clause head that is an identifier
; can only be `else`.
(define (f x) (case x ((1) "a") (otherwise "b")))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
