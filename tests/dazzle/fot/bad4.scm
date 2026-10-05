(element tdoc (make sequence (process-children)))
(element tbl (make table
  before-row-border: "x"
  (make table-column column-number: 0)
  (process-children)))
(element part (make table-part (process-children)))
(element tbl2 (make sequence (process-children)))
(element tbl3 (make table (process-children)))
(element row (make table-row (process-children)))
(element cell (make table-cell (process-children)))
(element wide (make table-cell n-columns-spanned: 2 (process-children)))
(element tall (make table-cell n-rows-spanned: 2 (process-children)))
(element kcell (make table-cell n-rows-spanned: (- 1 2) (process-children)))
