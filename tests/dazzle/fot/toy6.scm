(element doc (make sequence (process-children)))
(element title
  (make paragraph
    font-size: (* 2 (actual-line-spacing))
    (make display-group
      line-spacing: 20pt
      (process-children))))
(element p (make paragraph
  font-size: 24pt
  line-spacing: (* 1.5 (actual-font-size))
  (process-children)))
(element em (make sequence
  font-size: (* 2 (actual-line-spacing))
  (process-children)))
