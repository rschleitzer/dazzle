<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
(root (process-children))
(element suite
  (make fi data: (string-append
    "TR=" (gi (node-property 'tree-root (node-list-first (children (current-node)))))
    " GR=" (number->string (node-list-length (node-property 'grove-root (current-node) default: (empty-node-list))))
    " NP=" (if (node-property 'no-such-prop (current-node) default: #f) "yes" "no"))))
(element grp (empty-sosofo))
(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
