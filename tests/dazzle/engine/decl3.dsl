<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<style-sheet>
<!-- add-name-chars changes the DSSSL LEXER, so the proof is that a name
     CONTAINING the character reads as one identifier. Without the
     declaration phase running, `a@b` is not a name and the parse fails - the
     control run for that is decl3b, which is the same stylesheet with the
     declaration removed. -->
<add-name-chars>
commercial-at
</add-name-chars>
<style-specification id="main">
<style-specification-body>
<![CDATA[
(declare-flow-object-class fi "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(root (process-children))
(element doc (process-children))
(define a@b "AT-OK ")
(element p (make fi data: a@b))
]]>
</style-specification-body>
</style-specification>
</style-sheet>
