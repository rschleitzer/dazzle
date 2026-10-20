<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- headers and footers: each part an area of blocks across the body's
     width, a paragraph that says start set as its part says (left, center,
     right), one with its own quadding, two paragraphs in one part, the page
     number; with header-margin and footer-margin, and without them in the
     middle of the page margin -->
(element doc (process-children))
(element part
  (let ((m (equal? (attribute-string "margins") "yes")))
    (make simple-page-sequence
      page-width: 140mm page-height: 120mm
      left-margin: 20mm right-margin: 20mm top-margin: 25mm bottom-margin: 22mm
      header-margin: (if m 8mm 0pt)
      footer-margin: (if m 6mm 0pt)
      font-family-name: "Times New Roman" font-size: 10pt line-spacing: 12pt
      left-header: (make sequence font-size: 8pt (literal "Links oben"))
      center-header: (make sequence
                       (make paragraph font-weight: 'bold (literal "Der Titel"))
                       (make paragraph font-size: 8pt (literal "und eine Zeile darunter")))
      right-header: (make paragraph quadding: 'start font-size: 8pt (literal "rechts, aber start"))
      left-footer: (make paragraph quadding: 'end font-size: 8pt (literal "links, aber end"))
      center-footer: (make sequence (literal "Seite ") (page-number-sosofo))
      right-footer: (make sequence font-posture: 'italic font-size: 9pt (literal "rechts unten"))
      (process-children))))
(element p
  (make paragraph space-after: 4pt (process-children)))
