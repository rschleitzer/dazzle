<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION>
<![CDATA[
(root (process-children))
(element SUITE
  (literal
    (apply string-append
      (map (lambda (t) (string-append (attribute-string "ID" t) ","))
           (node-list->list (select-elements (descendants (current-node)) "TEST"))))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
