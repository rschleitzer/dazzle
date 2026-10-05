(element doc (make simple-page-sequence
  left-header: "oops"
  center-footer: 42
  (process-children)))
(element title (make paragraph
  left-header: (literal "x")
  (process-children)))
(element p (make paragraph (process-children)))
(element em (empty-sosofo))
