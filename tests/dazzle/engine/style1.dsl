<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; style1 - DSSSL2 STYLE RULES (SchemeParser::parseRuleBody's keyword arm).
; A rule body that STARTS WITH A KEYWORD sets characteristics instead of
; building a flow object; the node's matching style rules are all pushed onto
; the style stack, then the one construction rule builds. Without -2 the same
; file is a parse error, which is what style1b pins.
(root (process-children))
(element doc (make simple-page-sequence (process-children)))
(element p (make paragraph (process-children)))

; one rule, several characteristics
(element p font-size: 14pt font-weight: (quote bold) quadding: (quote center))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
