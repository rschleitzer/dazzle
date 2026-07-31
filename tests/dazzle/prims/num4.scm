; num4.scm - the NUMBERING family: ancestor-child-number,
; hierarchical-number, element-number-list, first-child-gi and
; node-list-no-order, alongside the three that were already ported
; (child-number, element-number, hierarchical-number-recursive) so the whole
; cluster is pinned together.
;
; The document is three chapters, the middle one with two sections, so a
; probe paragraph has a real (chapter, section, paragraph) coordinate and the
; RESET semantics of element-number-list are visible: the paragraph numbers
; restart per section, the section numbers per chapter.
;
; ★It also pins general-name-normalize, which folds a GI with the parse's
; general substitution table — the lowercase names written here reach
; elements stored upper-cased, and every GI-matching primitive below depends
; on that same fold.
;
; ASCII ONLY, and MARKUP-FREE (see num1.scm).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (show v)
  (cond ((number? v) (number->string v))
        ((string? v) (string-append "s:" v))
        ((boolean? v) (if v "#t" "#f"))
        ((null? v) "()")
        ((pair? v) (string-append "(" (show (car v)) " " (show (cdr v)) ")"))
        (else "?")))
(define (p tag v) (out (string-append tag "=" (show v))))

; the probe is the second paragraph of the first section of chapter two
(define (probe) (element-with-id "probe"))

(element doc (make sequence

  ; --- general-name-normalize (the fold every GI match below relies on) ---
  (p "gnn-lower"  (general-name-normalize "chap"))
  (p "gnn-upper"  (general-name-normalize "CHAP"))
  (p "gnn-miss"   (general-name-normalize "no-such"))

  ; --- ancestor-child-number: the NEAREST ancestor with that GI ----------
  (p "acn-chap"   (ancestor-child-number "chap" (probe)))
  (p "acn-sec"    (ancestor-child-number "sec" (probe)))
  (p "acn-doc"    (ancestor-child-number "doc" (probe)))
  (p "acn-miss"   (ancestor-child-number "nosuch" (probe)))
  ; a node is NOT its own ancestor - the walk starts at the parent
  (p "acn-self"   (ancestor-child-number "p" (probe)))
  ; upper case reaches the same element through the fold
  (p "acn-upper"  (ancestor-child-number "SEC" (probe)))

  ; --- hierarchical-number: outermost first ------------------------------
  (p "hn-3"       (hierarchical-number (list "chap" "sec" "p") (probe)))
  (p "hn-2"       (hierarchical-number (list "chap" "sec") (probe)))
  (p "hn-1"       (hierarchical-number (list "chap") (probe)))
  (p "hn-empty"   (hierarchical-number (list) (probe)))
  ; a GI that is nowhere above scores 0, and everything ABOVE it does too -
  ; the ancestor walk is consumed, not restarted
  (p "hn-miss"    (hierarchical-number (list "nosuch" "sec" "p") (probe)))
  (p "hn-missin"  (hierarchical-number (list "chap" "nosuch" "p") (probe)))

  ; --- element-number-list: each level counted since the next one's reset -
  (p "enl-3"      (element-number-list (list "chap" "sec" "p") (probe)))
  (p "enl-2"      (element-number-list (list "chap" "sec") (probe)))
  (p "enl-1"      (element-number-list (list "p") (probe)))
  (p "enl-empty"  (element-number-list (list) (probe)))
  ; the already-ported plain element-number, for contrast: NOT reset
  (p "en-p"       (element-number (probe)))
  (p "en-sec"     (element-number (ancestor "sec" (probe))))
  (p "cn-p"       (child-number (probe)))
  (p "hnr-chap"   (hierarchical-number-recursive "chap" (probe)))

  ; --- first-child-gi -----------------------------------------------------
  (p "fcg-doc"    (first-child-gi (current-node)))
  (p "fcg-chap"   (first-child-gi (ancestor "chap" (probe))))
  (p "fcg-sec"    (first-child-gi (ancestor "sec" (probe))))
  ; a paragraph whose first child is DATA, not an element
  (p "fcg-p"      (first-child-gi (probe)))
  ; an EMPTY node-list is #f, not a diagnostic
  (p "fcg-empty"  (first-child-gi (empty-node-list)))

  ; --- node-list-no-order: same members, same order -----------------------
  (p "nlno-len"   (node-list-length (node-list-no-order (children (current-node)))))
  (p "nlno-gi"    (gi (node-list-first (node-list-no-order (children (current-node))))))
  (p "nlno-eq"    (node-list=? (node-list-no-order (children (current-node)))
                               (children (current-node))))
))
(default (empty-sosofo))
