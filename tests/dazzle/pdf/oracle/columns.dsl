<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- column sets (Dazzle.Pdf's column-set and balance-columns?): two
     columns over two pages with a column break, a heading kept with its
     paragraph into the next column, a table in a column; three balanced
     columns ending in the middle of a page; a set to be balanced with a
     column break on its last page, which is not; and the first page's own
     margins (first-page-top-margin, first-page-bottom-margin) -->
(declare-characteristic column-set
  "UNREGISTERED::Dazzle//Characteristic::column-set" "")
(declare-characteristic balance-columns?
  "UNREGISTERED::Dazzle//Characteristic::balance-columns?" #f)
(declare-characteristic first-page-top-margin
  "UNREGISTERED::Dazzle//Characteristic::first-page-top-margin" 0pt)
(declare-characteristic first-page-bottom-margin
  "UNREGISTERED::Dazzle//Characteristic::first-page-bottom-margin" 0pt)
(element doc
  (make simple-page-sequence
    page-width: 150mm page-height: 160mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    first-page-top-margin: 30mm first-page-bottom-margin: 20mm
    font-family-name: "Times New Roman" font-size: 10pt line-spacing: 12pt
    (process-children)))
(element p (make paragraph space-after: 4pt (process-children)))
(element h (make paragraph font-weight: 'bold keep-with-next?: #t space-before: 6pt space-after: 3pt (process-children)))
(element brk (make paragraph break-before: 'column))
(element cols
  (make display-group
    column-set: (attribute-string "set")
    balance-columns?: (equal? (attribute-string "balance") "yes")
    space-before: 6pt space-after: 6pt
    (process-children)))
(element table (make table table-border: #t (process-children)))
(element row (make table-row (process-children)))
(element cell
  (make table-cell cell-before-column-margin: 2pt cell-after-column-margin: 2pt
    (make paragraph (process-children))))
