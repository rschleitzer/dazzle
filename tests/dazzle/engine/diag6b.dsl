<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; the same rule inside a mode group (parseModeGroup's keyId arm).
(declare-flow-object-class fi "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(root (process-children))
(element doc (with-mode m (process-children)))
(mode m
  (element p (make fi data: "DEF "))
  (id "p2" (make fi data: "ID2 ")))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
