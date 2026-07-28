(define rgb (color-space "ISO/IEC 10179:1996//Color-Space Family::Device RGB"))
(define gray (color-space "ISO/IEC 10179:1996//Color-Space Family::Device Gray"))
(define cmyk (color-space "ISO/IEC 10179:1996//Color-Space Family::Device CMYK"))
(define kx (color-space "ISO/IEC 10179:1996//Color-Space Family::Device KX"))
(define luv (color-space "ISO/IEC 10179:1996//Color-Space Family::CIE LUV"
  white-point: (list 0.9505 1.0 1.089)
  range: (list 0 100 -200 200 -200 200)))
(define lab (color-space "ISO/IEC 10179:1996//Color-Space Family::CIE LAB"
  white-point: (list 0.9505 1.0 1.089) range: (list 0 100 -100 100 -100 100)))
(define abc (color-space "ISO/IEC 10179:1996//Color-Space Family::CIE Based ABC"
  white-point: (list 0.9505 1.0 1.089)
  decode-abc: (list (lambda (x) (* x x)) (lambda (x) x) (lambda (x) x))
  range-lmn: (list 0 2 0 2 0 2)))
(define csa (color-space "ISO/IEC 10179:1996//Color-Space Family::CIE Based A"
  white-point: (list 0.9505 1.0 1.089)
  decode-a: (lambda (x) (/ x 2))
  range-lmn: (list 0 2 0 2 0 2)))
(element tdoc (make sequence
  color: (color rgb 1 0 0.5)
  background-color: (color gray 0.25)
  (process-children)))
(element tbl (make table
  color: (color cmyk 0.1 0.2 0.3 0.1)
  background-color: #f
  space-before: (display-space 6pt min: 2pt max: 10pt priority: 2 conditional?: #f)
  space-after: (display-space 4pt priority: 'force)
  (make table-column width: (table-unit 1))
  (make table-column column-number: 2 width: (+ 50pt (table-unit 2)))
  (make table-column column-number: 3 width: (* (display-size) 1.5))
  (process-children)))
(element part (make table-part (process-children)))
(element row (make table-row (process-children)))
(element cell (make table-cell color: (inherited-color) (process-children)))
(element wide (make table-cell n-columns-spanned: 2 (process-children)))
(element tall (make table-cell n-rows-spanned: 2 (process-children)))
(element tbl2 (make table
  space-before: (+ 12pt (* (display-size) 0.5))
  min-leading: 2pt
  min-pre-line-spacing: #f
  (process-children)))
(element tbl3 (make sequence
  color: (color luv 50 20 30)
  background-color: (color kx 0.5 0.25)
  (make paragraph
    background-color: (color lab 50 20 30)
    escapement-space-before: (inline-space 3pt min: 1pt max: 5pt)
    escapement-space-after: 2pt
    inline-space-space: (inline-space 1pt)
    min-leading: #f
    (process-children))))
(element kcell (make paragraph
  color: (if (and (color? (color abc 0.5 0.5 0.5)) (color-space? csa)
                  (display-space? (display-space 1pt))
                  (inline-space? (inline-space 1pt)))
             (color csa 0.5)
             (color rgb 0 0 0))
  (process-children)))
