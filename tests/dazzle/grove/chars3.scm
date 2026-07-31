; chars3.scm - the CHARACTER STREAM of the entity-reference node classes:
; what ProcessContext hands the backend when it walks a content run containing
; an sdata / external-data / pi-entity / subdocument / non-sgml node.
;
; ASCII ONLY, and no angle brackets AND NO AMPERSANDS in comments (the .scm is
; included as an SGML entity, so an entity reference in a comment is parsed).
;
; This is the observable that reaches all six backends: Node::getChar is
; implemented in terms of charChunk, and only data-char and sdata answer it.
; An sdata node contributes the ONE character its entity maps to
; (Interpreter::sdataMap: the built-in name table, then the text table, then
; convertUnicodeCharName, then defaultChar) - never its replacement text.
; external-data, subdocument and non-sgml contribute NOTHING.
;
; *The q paragraphs (whose sdata entity resolves to the FALLBACK defaultChar,
; U+FFFD) report their data LENGTH instead of their characters, deliberately:
; the reference's sgml backend escapes a character its output coding system
; cannot represent as a numeric reference while this port writes UTF-8
; unconditionally - the open OutputEncoder item of COMPLETENESS.md gap (6),
; which has nothing to do with these node classes.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define (out s) (make fi data: s))

; ProcessContext::processNode tests charChunk FIRST and only falls through to
; rule matching when it is not accessOK - so the {D} marker below shows exactly
; which of these classes reaches the DEFAULT RULE at all (sdata does not; the
; other four do).
(root (process-children))
(default
  (make sequence
    (out "{D}")
    (process-children)))

(element p
  (make sequence
    (out "[")
    (process-children)
    (out "]
")))

(element q
  (out (string-append "[len="
                      (number->string (string-length (data (current-node))))
                      "]
")))
