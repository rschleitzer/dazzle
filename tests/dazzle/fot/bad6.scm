(element doc (make sequence (process-children)))
(element title (make paragraph
  (make line-field
    break-before-priority: 2
    break-after-priority: "bogus"
    (process-children))))
(element p (make paragraph
  (make line-field
    break-before-priority: (if (string? (gi (current-node))) "bad" 3)
    (process-children))))
(element em (make paragraph-break (literal "dropped")))
