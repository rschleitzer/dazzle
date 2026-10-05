<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; diag7c - the same missing check seen on the OUTPUT, not on stderr: a
; top-level define is computed with no processing mode (Identifier::
; computeValue evaluates in an empty context), so `pc` is an ERROR OBJECT in
; the reference and contributes nothing. Without the check the port built a
; sosofo with a NULL mode instead, which then processed the children a second
; time - `oneonetwotwo` where the reference says `onetwo`.
(define pc (process-children))
(root (process-children))
(element doc (process-children))
(mode m
  (element p (literal "M")))
(element p (make sequence pc (with-mode m (process-children))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
