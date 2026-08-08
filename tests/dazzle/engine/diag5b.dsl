<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
(root (empty-sosofo))
; Interpreter::addCharProperty's part arbitration -> duplicateAddCharProperty
; when the SAME part sets the same character twice to different values. The
; same value twice is silent, and that half is pinned here too.
(declare-char-property my-p 1)
(add-char-properties my-p: 7 #\a)
(add-char-properties my-p: 7 #\a)
(add-char-properties my-p: 9 #\a)
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
