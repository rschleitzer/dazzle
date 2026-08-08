<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; style5 - a construction rule body that is NOT a sosofo. Ported with the
; style rules because it is the same line: Action::compile guards a
; CONSTRUCTION rule's body with a CheckSosofoInsn and a STYLE rule's body
; with nothing. Before that this file was silent.
(root (process-children))
(element doc (make simple-page-sequence (process-children)))
(element p 42)
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
