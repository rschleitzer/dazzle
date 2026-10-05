(element doc (make sequence (process-children)))
(element title (make paragraph use: tit-style (process-children)))
(element p
  (make paragraph
    space-before: (if (attribute-string "id" (current-node)) 24pt 6pt)
    (make line-field field-width: 8pt (literal "x"))
    (process-children)
    (make paragraph-break)))
(element em (empty-sosofo))
(define tit-style (style font-size: 14pt font-family-name: "iso-sanserif" lines: 'asis))
