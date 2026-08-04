<!DOCTYPE STYLE-SHEET [
<!ELEMENT style-sheet o o ((style-specification)+)>
<!ELEMENT style-specification o o (style-specification-body)>
<!ATTLIST style-specification id id #implied use idrefs #implied>
<!ELEMENT style-specification-body o o (#pcdata)>
<!ATTLIST style-specification-body content entity #conref>
<!NOTATION DSSSL PUBLIC "ISO/IEC 10179:1996//NOTATION DSSSL Architecture Definition Document//EN">
]>
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
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
