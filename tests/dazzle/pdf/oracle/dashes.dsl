<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- line-dash (OpenJade 1.5.0, Dazzle.Pdf 0.9.0): the first length is the
     offset into the pattern, the others alternately dash and gap; an even and
     an odd pattern, an offset, a pattern of zeros (solid), a dashed score, and
     the borders of a table and of a cell with patterns of their own -->
(define (dash-of name)
  (cond ((equal? name "even") (list 0pt 6pt 3pt))
        ((equal? name "odd") (list 0pt 4pt 2pt 1pt))
        ((equal? name "offset") (list 3pt 6pt 3pt))
        ((equal? name "zero") (list 0pt 0pt 0pt))
        (else (list 0pt))))
(element doc
  (make simple-page-sequence
    page-width: 140mm page-height: 120mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 10pt line-spacing: 12pt
    (process-children)))
(element p (make paragraph space-after: 4pt (process-children)))
(element rule
  (make rule orientation: 'horizontal line-thickness: 1pt
    line-dash: (dash-of (attribute-string "dash"))
    space-before: 4pt space-after: 4pt))
(element u (make score type: 'after line-dash: (list 0pt 2pt 1pt) (process-children)))
(element table
  (make table
    table-border: (make table-border line-thickness: 1pt line-dash: (list 0pt 5pt 2pt))
    space-before: 6pt
    (process-children)))
(element row (make table-row (process-children)))
(element cell
  (make table-cell
    cell-before-row-border: (if (equal? (attribute-string "own") "yes")
                               (make table-border line-thickness: 2pt line-dash: (list 1pt 3pt 1pt))
                               #f)
    cell-before-column-margin: 3pt cell-after-column-margin: 3pt
    (make paragraph (process-children))))
