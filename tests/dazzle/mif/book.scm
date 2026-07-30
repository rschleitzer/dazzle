(element doc (make sequence (process-children)))
(element title (make simple-page-sequence
  left-header: (literal "H1")
  (make paragraph (process-children))))
(element p (make simple-page-sequence
  right-footer: (current-node-page-number-sosofo)
  (make paragraph (process-children))))
(element em (make sequence (process-children)))
