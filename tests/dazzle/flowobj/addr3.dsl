<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; addr3 - the RENDERING side: what each backend makes of each Address type
; behind the `link` flow object's destination:.
;
; The root rule walks the eight forms once. The element rule then walks the
; resolvedNode arm over the three p's of the document - two with an ID, one
; without - because that arm forks on getId before elementIndex.

(root
  (make simple-page-sequence

    ; no destination: at all - addressObj_ stays null, which processInner
    ; turns into a fresh Address::none
    (make link (literal "L0"))

    ; #f - the same none, by way of makeAddressNone
    (make link destination: #f (literal "L1"))

    ; a resolved node that is NOT an element: the grove root. fot checks
    ; nodeIsElement, tex warns, rtf/mif/html find no element index.
    (make link destination: (current-node-address) (literal "L2"))

    ; a resolved node that IS an element, reached through node-list-address
    (make link destination: (node-list-address (element-with-id "alpha"))
      (literal "L3"))

    ; idref - the string is kept, not resolved, so a forward or unknown
    ; reference is no error here
    (make link destination: (idref-address "alpha") (literal "L4"))

    ; two IDREFs: rtf, mif and html cut at the first space, fot keeps the
    ; whole attribute value
    (make link destination: (idref-address "alpha beta") (literal "L5"))

    ; an ID no element carries
    (make link destination: (idref-address "nosuch") (literal "L6"))

    ; the three types no backend renders
    (make link destination: (entity-address "pic") (literal "L7"))
    (make link destination: (sgml-document-address "other.sgml" "topid")
      (literal "L8"))
    (make link destination: (hytime-linkend) (literal "L9"))

    (process-children)))

; the resolvedNode fork, once per p: alpha and beta have an ID, the third
; has none and falls through to the element index.
(element p
  (make link destination: (current-node-address) (process-children)))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
