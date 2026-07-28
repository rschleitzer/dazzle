; rule / fraction-bar / glyph-subst-table error paths
(define T (glyph-subst-table (list (cons (glyph-id "x") (glyph-id "y::3")))))
(element doc
  (make display-group
    fraction-bar: 5
    glyph-subst-table: 7
    (process-children)))
(element title
  (make paragraph
    fraction-bar: (make paragraph)
    glyph-subst-table: (list T 9)
    (make rule
      orientation: 'diagonal
      length: "wide"
      (literal "inside"))
    (process-children)))
(element p
  (make paragraph
    (literal (if (glyph-subst-table? (glyph-subst-table (list 4))) "a" "b"))
    (literal (if (glyph-id? (glyph-subst 6 (glyph-id "z"))) "c" "d"))
    (literal (if (glyph-id? (glyph-subst T "nope")) "e" "f"))
    (literal (if (glyph-id? (glyph-id 8)) "g" "h"))
    (process-children)))
(element em (make sequence (process-children)))
