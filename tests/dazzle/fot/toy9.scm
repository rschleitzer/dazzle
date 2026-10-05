(element tdoc (make sequence (process-children)))
(element tbl (make table (process-children)))
(element part
  (make table-part
    content-map: '((hd header) (ft footer) (bd #f))
    (let loop ((rows (select-elements (children (current-node)) "row")) (i 1))
      (if (node-list-empty? rows)
          (empty-sosofo)
          (make sequence
            (make sequence
              label: (cond ((equal? i 1) 'hd) ((equal? i 4) 'ft) (else 'bd))
              (process-node-list (node-list-first rows)))
            (loop (node-list-rest rows) (+ i 1)))))))
(element row (make table-row (process-children)))
(element cell (make table-cell (process-children)))
(element wide (make table-cell n-columns-spanned: 2 (process-children)))
(element tall (make table-cell n-rows-spanned: 2 (process-children)))
(element tbl2
  (make table
    (make table-part
      content-map: '((h2 header) (h3 header))
      (make sequence
        label: 'h2
        (make paragraph (literal "outer-h"))
        (make sequence
          label: 'h3
          (make paragraph (literal "nested-h"))))
      (process-children))))
(element tbl3 (make paragraph (process-children)))
(element kcell (make paragraph (process-children)))
