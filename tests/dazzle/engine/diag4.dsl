<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; diag4 - ProcessContext::processNodeSafe's loop guard. Before 2026-08-08 the
; port called processNode directly here, so this stylesheet did not report a
; loop: it recursed until the stack gave out (rc 139, no output at all).
(root (process-children))
(element doc (process-children))
(element p (process-node-list (current-node)))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
