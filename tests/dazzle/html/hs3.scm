; hs3 - the html backend's IDREF link arm. HtmlFOTBuilder::startLink is the
; only backend that RESOLVES an idref address itself, walking
; getGroveRoot, getElements, namedNode, elementIndex; every step must
; succeed or the anchor comes out without an HREF.
;
; The probes, in order: the id of an element that exists (the anchor is
; emitted for it and referenced), the same id with a second one after a
; space (cut at the first space), an id no element carries, an id in the
; document's own case (the ID attribute is namecase-folded to FIRST, so the
; lower-case form must fold too before it can match), and - for contrast -
; the resolvedNode form hs1 already pins.

(element doc
  (make scroll
    (process-children)))

(element title
  (make paragraph
    font-weight: 'bold
    (process-children)))

(element p
  (make paragraph
    (make sequence
      (make link destination: (idref-address "FIRST") (literal "a"))
      (make link destination: (idref-address "FIRST OTHER") (literal "b"))
      (make link destination: (idref-address "nosuch") (literal "c"))
      (make link destination: (idref-address "first") (literal "d"))
      (make link destination: (idref-address "") (literal "e"))
      (make link destination: (node-list-address (element-with-id "FIRST"))
        (literal "f"))
      (process-children))))

(element em (process-children))
