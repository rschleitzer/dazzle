<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<style-sheet>
<!-- decl1 - the DECLARATION PHASE (StyleEngine.cxx:40-80), which this port
     gathered but never executed until 2026-08-08. A `standard-chars` at
     STYLE-SHEET level lands on the DOC's declaration list, which is the half
     the reference walks first. Without the phase, `#\mychar` is an unknown
     character name and the output is a replacement character. -->
<standard-chars>
mychar 65
otherchar 66
</standard-chars>
<style-specification id="main">
<style-specification-body>
<![CDATA[
(declare-flow-object-class fi "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(root (process-children))
(element doc (process-children))
(element p (make fi data: (string #\mychar #\otherchar)))
]]>
</style-specification-body>
</style-specification>
</style-sheet>
