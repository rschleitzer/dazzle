(element tdoc (make sequence (process-children)))
(element tbl (make table (process-children)))
(element part
  (make table-part
    content-map: '((hd header) bogus (x nofoo))
    (make sequence
      label: 'nowhere
      (make paragraph (literal "lost")))
    (process-children)))
(element row (make table-row (process-children)))
(element cell (make table-cell (process-children)))
(element wide (make table-cell (process-children)))
(element tall (make table-cell (process-children)))
(element tbl2 (make paragraph content-map: 17 (process-children)))
(element tbl3 (make sequence (process-children)))
(element kcell (make sequence label: "notasym" (make paragraph (process-children))))
