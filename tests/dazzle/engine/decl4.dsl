<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<style-sheet>
<!-- the reference's `default:` arm: any declaration kind it does not handle
     is a WARNING with no location (`interpreter_->message` without a
     preceding setNextLocation) and is ignored. It is deliberately NOT
     emitted for the five kinds above - a half-built phase that warned about
     them would be worse than none. -->
<features>keyword
</features>
<style-specification id="main">
<style-specification-body>
<![CDATA[
(declare-flow-object-class fi "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(root (process-children))
(element doc (process-children))
(element p (make fi data: "P "))
]]>
</style-specification-body>
</style-specification>
</style-sheet>
