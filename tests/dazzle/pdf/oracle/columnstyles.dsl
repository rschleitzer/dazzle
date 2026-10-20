<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- a table whose columns are elements of their own beside its rows: their
     styles (font-weight of the first) are pushed by the cells long after
     the column's own rule is done, and the row heights are bound with let*
     in the row's rule; and an image given as a PDF, drawn as a form -->
(declare-characteristic row-height
  "UNREGISTERED::Dazzle//Characteristic::row-height" 0pt)
(declare-characteristic grows-line?
  "UNREGISTERED::Dazzle//Characteristic::grows-line?" #t)
(define (points name nd)
  (let ((s (attribute-string name nd)))
    (if (and s (not (string=? s ""))) (* (string->number s) 1pt) 0pt)))
(element doc
  (make simple-page-sequence
    page-width: 150mm page-height: 120mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 10pt line-spacing: 12pt
    (process-children)))
(element p (make paragraph space-after: 4pt (process-children)))
(element table (make table table-border: #t space-after: 6pt (process-children)))
(element col
  (make table-column
    width: (points "width" (current-node))
    font-weight: (if (equal? (attribute-string "bold") "yes") 'bold 'medium)))
(element row
  (let* ((nd (current-node)) (h (points "h" nd)))
    (make table-row row-height: h (process-children))))
(element cell
  (make table-cell cell-before-column-margin: 2pt cell-after-column-margin: 2pt
    (make paragraph (process-children))))
(element box
  (make sequence
    position-point-shift: (points "shift" (current-node))
    grows-line?: #f
    (make external-graphic entity-system-id: "box.pdf")))
