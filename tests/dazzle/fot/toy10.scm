; rule + fraction-bar + glyph-subst-table (the dbprint *small-caps* shape)
(define make-afii
  (lambda (n) (glyph-id (string-append "ISO/IEC 10036/RA//Glyphs::"
                                       (number->string n)))))
(define *small-caps*
  (letrec ((signature (* 253 256))
           (gen
            (lambda (from count)
              (if (= count 0)
                  '()
                  (cons (cons (make-afii from)
                              (make-afii (+ from signature)))
                        (gen (+ 1 from) (- count 1)))))))
    (glyph-subst-table (gen 97 4))))
(define *other*
  (glyph-subst-table (list (cons (glyph-id "foo") (glyph-id "bar::2")))))
(element doc
  (make display-group
    glyph-subst-table: *small-caps*
    (process-children)))
(element title
  (make paragraph
    glyph-subst-table: (list *small-caps* *other*)
    fraction-bar: (make rule orientation: 'horizontal)
    (make rule
      orientation: 'horizontal
      line-thickness: 2pt
      display-alignment: 'center
      space-after: 2pt
      keep-with-next?: #t)
    (process-children)))
(element p
  (make sequence
    glyph-subst-table: #f
    (make rule
      orientation: 'escapement
      length: 36pt
      break-before-priority: 1
      break-after-priority: 2)
    (make rule
      orientation: 'vertical
      length: (* (display-size) 0.5)
      space-before: 1pt)
    (make paragraph
      fraction-bar: (inherited-fraction-bar)
      glyph-subst-table: (inherited-glyph-subst-table)
      (literal
        (if (and (glyph-id? (glyph-subst *small-caps* (make-afii 97)))
                 (glyph-subst-table? *other*)
                 (not (glyph-id? 5))
                 (not (glyph-subst-table? 5)))
            "ok "
            "bad "))
      (process-children))))
(element em
  (make sequence
    glyph-subst-table: (inherited-glyph-subst-table)
    (process-children)))
