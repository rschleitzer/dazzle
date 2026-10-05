; The output-encoder probe: every stream a backend writes gets a char the
; coding system may or may not be able to express.
;   - the document's own text (whatever the INPUT decoder made of its bytes)
;   - U+20AC, written as the DSSSL \U- escape so the stylesheet source
;     stays pure ASCII and decodes the same under every SP_ENCODING
(root
  (make sequence
    (process-children)))
; `scroll` around the content, because the HTML backend opens a DOCUMENT file
; (its second encoded stream, next to the stylesheet) only for a scroll:
; HtmlFOTBuilder::startScroll is where a Document is built.
(element doc
  (make scroll
    (make paragraph
      (literal "[\U-20AC]")
      (process-children))))
(element em
  (make paragraph
    (literal "em:")
    (process-children)))
