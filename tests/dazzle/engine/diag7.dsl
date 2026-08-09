<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; diag7 - the process-* family called with NO current processing mode.
; A declare-initial-value body is evaluated outside every rule, so each of
; these is the reference's `if (!context.processingMode)` arm.
(declare-initial-value font-size
  (if (sosofo? (process-children)) 10pt 12pt))
(declare-initial-value line-spacing
  (if (sosofo? (process-children-trim)) 10pt 12pt))
; the mode test runs BEFORE the argument test: 42 is not a node list, and the
; reference still reports the context.
(declare-initial-value start-indent
  (if (sosofo? (process-node-list 42)) 0pt 1pt))
(root (process-children))
(element doc (process-children))
(element p (literal "x"))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
