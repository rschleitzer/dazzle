<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; style4 - the other rule FORMS carry style rules too: default, root, a mode
; group, and an id rule. A more specific style rule does NOT report an
; ambiguity - it simply wins, which is the whole point of specificity.
(root (process-children))
(root font-size: 9pt)
(element doc (make simple-page-sequence (with-mode m (process-children))))
(element p (make paragraph (process-children)))
(default font-weight: (quote bold))
(mode m (element p font-posture: (quote italic)))
(id "p2" quadding: (quote center))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
