<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; style2 - the ORDER of equally specific style rules, which is a CONTRACT here
; where it is not one for construction rules: every matching style rule
; applies, so the run order decides which specification of a characteristic
; wins and in which order they reach the backend. The reference keeps element
; rules in an IList that PREPENDS, so the run is LAST-DECLARED-FIRST.
(root (process-children))
(element doc (make simple-page-sequence (process-children)))
(element p (make paragraph (process-children)))
(element p font-size: 10pt)
(element p font-weight: (quote bold))
(element p font-posture: (quote italic))
(element p quadding: (quote center))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
