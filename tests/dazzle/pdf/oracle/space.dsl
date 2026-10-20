<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- space between blocks: the larger of after and before, conditional space
     dropped at the top of a page, space that is not conditional kept there -->
(element doc
  (make simple-page-sequence
    page-width: 150mm page-height: 120mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 11pt line-spacing: 14pt
    (process-children)))
(element sect
  (if (first-sibling?)
      (make display-group (process-children))
      (make display-group break-before: 'page (process-children))))
(element title
  (make paragraph
    font-family-name: "Arial" font-weight: 'bold font-size: 13pt line-spacing: 16pt
    space-before: (display-space 20pt
                    conditional?: (not (equal? (attribute-string "kind" (parent)) "fixed")))
    space-after: 6pt
    (process-children)))
(element p
  (let ((kind (attribute-string "kind")))
    (make paragraph
      space-before: (cond ((equal? kind "wide") 18pt)
                          ((equal? kind "fixed") (display-space 9pt conditional?: #f))
                          (else 0pt))
      space-after: (if (equal? kind "wide") 12pt 4pt)
      (process-children))))
