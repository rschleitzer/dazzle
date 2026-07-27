(element doc (make display-group
  keep-with-next?: #t
  (process-children)))
(element title (make paragraph
  font-size: 18pt
  font-weight: 'bold
  quadding: 'center
  space-before: 12pt
  keep: 'page
  (process-children)))
(element p (make paragraph
  font-size: 10pt
  line-spacing: 12pt
  start-indent: 0.5pt
  first-line-start-indent: -3pt
  hyphenate?: #t
  country: #f language: "DE"
  (process-children)))
(element em (make sequence
  font-posture: 'italic
  (process-children)))
