(element tdoc (make sequence
  color: "red"
  (process-children)))
(element tbl (make table
  background-color: 5
  space-before: (display-space 3pt priority: 'high)
  (make table-column width: (table-unit 1.5))
  (process-children)))
(element part (make table-part (process-children)))
(element row (make table-row (process-children)))
(element cell (make table-cell (process-children)))
(element wide (make table-cell (process-children)))
(element tall (make table-cell (process-children)))
(element tbl2 (make table
  min-leading: 'x
  escapement-space-before: #t
  (process-children)))
(element tbl3 (make paragraph
  color: (color (color-space "bogus") 1)
  background-color: (color (color-space "ISO/IEC 10179:1996//Color-Space Family::Device RGB" 1) 2 0 0)
  (process-children)))
(element kcell (make paragraph
  color: (color (color-space "ISO/IEC 10179:1996//Color-Space Family::CIE LUV") 1 2 3)
  space-before: (display-space 3pt min: 1pt max:)
  space-after: (display-space 3pt huh: 1)
  (process-children)))
