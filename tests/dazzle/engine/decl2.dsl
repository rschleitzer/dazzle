<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<style-sheet>
<style-specification id="main">
<!-- the same declaration on the PART, i.e. the `local` half of the
     reference's do-while, plus a map-sdata-entity that NAMES the character
     the standard-chars above defines: that pairing is why the reference runs
     two PHASES over all parts instead of one pass. -->
<standard-chars>
mychar 65
</standard-chars>
<map-sdata-entity name="myent">
mychar
</map-sdata-entity>
<style-specification-body>
<![CDATA[
(declare-flow-object-class fi "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(root (process-children))
(element doc (process-children))
(element p (make fi data: (string #\mychar)))
]]>
</style-specification-body>
</style-specification>
</style-sheet>
