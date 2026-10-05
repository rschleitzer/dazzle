<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; style3 - ambiguousStyle: two rules of EQUAL specificity setting the SAME
; characteristic at the same level. The message anchors at the rule already
; in force and carries the NEW one as its auxiliary line - the reverse of
; every other duplicate diagnostic in this engine - and the LAST-declared rule
; is the one whose value survives.
(root (process-children))
(element doc (make simple-page-sequence (process-children)))
(element p (make paragraph (process-children)))
(element p font-size: 10pt)
(element p font-size: 12pt)
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
