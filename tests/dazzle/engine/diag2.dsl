<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; diag2 (-2) - the dsssl2 half of the same class: the continuation arms and
; the splice arm. `call-with-current-continuation` only exists under -2.
(root (process-children))
(element doc (process-children))

; CallWithCurrentContinuationPrimitiveObj::call -> notAProcedure (a
; MessageType3 like argError: name, ordinal 1, printed object).
(element p (literal (call-with-current-continuation 5)))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
