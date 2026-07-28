(element doc (make simple-page-sequence
  page-width: 210mm
  page-height: 297mm
  left-header: (literal "L")
  center-header: (make sequence
    (literal "Page ")
    (page-number-sosofo))
  right-footer: (page-number-sosofo)
  (process-children)))
(element title (make paragraph
  font-size: 14pt
  quadding: 'center
  (process-children)))
(element p (make paragraph (process-children)))
(element em (make sequence (process-children)))
