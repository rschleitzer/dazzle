(element tdoc (make sequence (process-children)))
(element tbl (make table
  table-width: 400pt
  table-border: (make table-border line-thickness: 2pt)
  before-row-border: #t
  after-column-border: (make table-border line-thickness: 3pt)
  space-before: 6pt
  (make table-column width: 100pt)
  (make table-column column-number: 2 n-columns-spanned: 2 width: 150pt
    font-weight: 'bold)
  (process-children)))
(element part (make table-part
  keep-with-next?: #t
  (process-children)))
(element tbl2 (make table
  table-width: #f
  cell-before-row-border: #t
  (make table-column width: 80pt)
  (process-children)))
(element tbl3 (make table
  (process-children)))
(element row (make table-row font-posture: 'italic (process-children)))
(element cell (make table-cell (process-children)))
(element wide (make table-cell
  n-columns-spanned: 2
  cell-before-column-border: #t
  (process-children)))
(element tall (make table-cell
  n-rows-spanned: 2
  cell-after-row-border: (make table-border)
  (process-children)))
(element (kcell (s "s")) (make table-cell starts-row?: #t (process-children)))
(element kcell (make table-cell (process-children)))
