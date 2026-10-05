(element doc (make sequence (process-children)))
(element title
  (if (equal? (inherited-font-size) 10pt)
      (make paragraph (process-children))
      (make paragraph quadding: 'center (process-children))))
(element p (make paragraph
  font-size: (actual-line-spacing)
  line-spacing: (actual-font-size)
  (process-children)))
(element em (empty-sosofo))
