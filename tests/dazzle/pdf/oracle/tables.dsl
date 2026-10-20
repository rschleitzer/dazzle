<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- tables: cells spanning rows and columns, cell backgrounds under all
     the rows a cell spans, cell-row-alignment, a table of its own width
     standing where its display-alignment says, row-height and
     min-row-height (Dazzle.Pdf's extensions), a header row repeated on the
     next page, borders of the table and of its cells -->
(declare-characteristic min-row-height
  "UNREGISTERED::Dazzle//Characteristic::min-row-height" 0pt)
(declare-characteristic row-height
  "UNREGISTERED::Dazzle//Characteristic::row-height" 0pt)
(define (number-of name default)
  (let ((s (attribute-string name)))
    (if s (string->number s) default)))
(define (length-of name)
  (let ((s (attribute-string name)))
    (if s (* (string->number (substring s 0 (- (string-length s) 2))) 1pt) 0pt)))
(define shade
  (color (color-space "ISO/IEC 10179:1996//Color-Space Family::Device RGB") 0.85 0.9 0.95))
(element doc
  (make simple-page-sequence
    page-width: 150mm page-height: 150mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 10pt line-spacing: 12pt
    (process-children)))
(element p
  (make paragraph space-after: 4pt (process-children)))
(element table
  (let ((w (attribute-string "width"))
        (a (attribute-string "align")))
    (make table
      table-width: (if w (* (string->number (substring w 0 (- (string-length w) 2))) 1mm) #f)
      display-alignment: (cond ((equal? a "center") 'center) ((equal? a "end") 'end) (else 'start))
      table-border: #t
      space-after: 6pt
      (make table-part (process-children)))))
(element head (process-children))
(element row
  (if (equal? (gi (parent (current-node))) "head")
      (make table-row label: 'header (process-children))
      (make table-row
        row-height: (length-of "h")
        min-row-height: (length-of "minh")
        (process-children))))
(element cell
  (let ((v (attribute-string "valign")))
    (make table-cell
      n-columns-spanned: (number-of "span" 1)
      n-rows-spanned: (number-of "rows" 1)
      cell-before-row-margin: 2pt cell-after-row-margin: 2pt
      cell-before-column-margin: 3pt cell-after-column-margin: 3pt
      cell-background?: (equal? (attribute-string "shade") "yes")
      background-color: (if (equal? (attribute-string "shade") "yes") shade #f)
      cell-row-alignment: (cond ((equal? v "center") 'center) ((equal? v "end") 'end) (else 'start))
      cell-before-row-border: #t cell-after-row-border: #t
      cell-before-column-border: #t cell-after-column-border: #t
      (if (node-list-empty? (select-elements (children (current-node)) "p"))
          (make paragraph (process-children))
          (process-children)))))
