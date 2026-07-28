(element doc (make display-group
  (literal (format-number-list 5 "1" "."))
  (process-children)))
(element title (make paragraph
  (literal (format-number 3 "x"))
  (literal " ")
  (literal (format-number 3 ""))))
(element p (make paragraph
  (literal (format-number "no" "1"))
  (process-children)))
(element em (make sequence
  (literal (format-number 3 7))
  (process-children)))
