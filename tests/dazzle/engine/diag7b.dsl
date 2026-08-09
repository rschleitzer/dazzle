<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; diag7b - the CONTROL for diag7: the same three calls INSIDE a rule, where a
; processing mode exists. process-children and process-children-trim are
; ordinary sosofos; process-node-list reaches its ARGUMENT test and reports
; the argument type - which is what makes diag7's third line an order probe.
(root (process-children))
(element doc (process-children))
(element p
  (make sequence
    (process-children)
    (process-children-trim)
    (process-node-list 42)))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
