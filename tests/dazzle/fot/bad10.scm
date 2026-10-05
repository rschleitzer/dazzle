(element doc (make display-group
  (literal (format-number-list '(1 2) "1" 9))
  (process-children)))
(element title (make paragraph
  (literal (format-number-list '(1 "x") "1" "."))))
(element p (make paragraph
  (literal (format-number-list '(1 2 3) '("1") "."))
  (process-children)))
(element em (make sequence
  (literal (format-number-list '(1 2) '("1" 7) "."))
  (process-children)))
