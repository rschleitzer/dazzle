<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- links to another document (sgml-document-address), whose system
     identifier is the URI the link opens: a rectangle over the link's text
     on each line it is set on, as high as the line: a short link, one
     that breaks across lines, one in a score with a color, one around an
     image; a link to an element of this document is set as its content -->
(element doc
  (make simple-page-sequence
    page-width: 150mm page-height: 120mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 11pt line-spacing: 14pt
    (process-children)))
(element p (make paragraph space-after: 6pt (process-children)))
(element a
  (make link destination: (sgml-document-address (attribute-string "href") "")
    (process-children)))
(element u
  (make score type: 'after
    color: (color (color-space "ISO/IEC 10179:1996//Color-Space Family::Device RGB") 0 0.5 0.3)
    (process-children)))
(element ref
  (make link destination: (idref-address (attribute-string "to"))
    (process-children)))
(element fig (make external-graphic entity-system-id: "figure.png" display?: #f scale: 0.2))
