; axis1.scm - the DSSSL PARENT AXIS vs the STRUCTURAL (origin) edge.
;
; ChunkNode::getParent (spgrove/GroveBuilder.cxx:4978) returns accessNull for
; every node whose origin is the grove root, so the sgml-document node is NOT
; reachable along the parent axis and every ancestor walk stops at the document
; element - while getOrigin and getGroveRoot still see it. Every value below is
; a golden minted from the reference C++ dazzle.
;
; ASCII ONLY: the .scm is read as an 8-bit charset, so a typographic dash in a
; comment would be a "non SGML character" error.
;
; No root rule on purpose: with one, the reference's (process-children) at the
; grove root is a no-op (the sgml-document node has no `content` children), so
; the walk starts at the document element via the element rules.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

; class-name of a node-list, or EMPTY - an axis with no parent yields the
; empty node-list.
(define (cn n1)
  (if (node-list-empty? n1) "EMPTY"
      (symbol->string (node-property 'class-name n1 default: 'none))))

; the numbering/gi primitives answer #f on non-elements.
(define (numf v) (if (number? v) (number->string v) "#f"))
(define (strf v) (if (string? v) v "#f"))

(define (report tag nd)
  (make sequence
    (out (string-append tag " parent=" (cn (parent nd))))
    (out (string-append tag " origin="
                        (cn (node-property 'origin nd default: (empty-node-list)))))
    (out (string-append tag " grove-root=" (cn (node-property 'grove-root nd))))
    (out (string-append tag " tree-root="
                        (cn (node-property 'tree-root nd default: (empty-node-list)))))
    (out (string-append tag " anc-doc=" (cn (ancestor "doc" nd))))
    (out (string-append tag " have-anc-doc="
                        (if (have-ancestor? "doc" nd) "YES" "NO")))
    (out (string-append tag " child-number=" (numf (child-number nd))))
    ; the SIBLING axis has its own root rule: the document element has no
    ; siblings at all, so preced/follow are empty and the first-sibling
    ; predicates are #f while the last-sibling ones are #t.
    (out (string-append tag " first-sib=" (if (first-sibling? nd) "YES" "NO")))
    (out (string-append tag " last-sib=" (if (last-sibling? nd) "YES" "NO")))
    (out (string-append tag " abs-first-sib="
                        (if (absolute-first-sibling? nd) "YES" "NO")))
    (out (string-append tag " abs-last-sib="
                        (if (absolute-last-sibling? nd) "YES" "NO")))
    (out (string-append tag " gi-of-parent="
                        (let ((p (parent nd)))
                          (if (node-list-empty? p) "EMPTY" (strf (gi p))))))))

(element doc (make sequence
  (report "GROVEROOT" (node-property 'grove-root (current-node)))
  (report "DOCELEM" (current-node))
  (process-children)))
(element title (report "TITLE" (current-node)))
(element em (report "EM" (current-node)))
; only the em children, so no character data leaks into the golden
(element p (process-node-list (select-elements (children (current-node)) "em")))
(default (empty-sosofo))
