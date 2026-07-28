(element doc (make sequence (process-children)))
(element title (make paragraph
  font-size: 20pt
  start-indent: 10pt
  line-spacing: (* 2 (inherited-line-spacing))
  (process-children)))
(element p
  (let ((delta 5pt))
    (make paragraph
      font-size: (+ (inherited-font-size) 4pt)
      start-indent: (+ (inherited-start-indent) delta)
      quadding: (inherited-quadding)
      (make line-field field-width: (inherited-font-size) (literal "x"))
      (process-children))))
(define rel-style (style end-indent: (+ (inherited-end-indent) 2pt)))
(element em (make sequence
  use: rel-style
  font-size: (* 2 (inherited-font-size))
  font-posture: 'italic
  (process-children)))
