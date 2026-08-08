<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; diag6 - the (id ...) construction rule, which the audit found MISSING
; ALTOGETHER (SchemeParser::doId): `unknown top level form "id"` at top level,
; a silently dropped mode group inside (mode ...). It is OUTPUT-affecting, so
; this fixture pins the OUTPUT, not a diagnostic: p2 must take the id rule.
(declare-flow-object-class fi "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(root (process-children))
(element doc (process-children))
(element p (make fi data: "DEFAULT "))
(id "p2" (make fi data: "BY-ID "))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
