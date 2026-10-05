; proc1.scm - the PROCESS / SOSOFO / STYLE cluster:
; process-first-descendant, process-matching-children, sosofo-label,
; sosofo-discard-labeled, merge-style, style?, match-element? and
; inherited-element-attribute-string.
;
; The document nests chapters, sections and paragraphs with attributes at
; several levels, so the inherited walk has somewhere to climb and the two
; process-* primitives have both matching and non-matching candidates.
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
        (else "?")))
(define (p tag v) (out (string-append tag "=" (show v))))
(define (probe) (element-with-id "probe"))

(element doc (process-children))

; --- style? and merge-style ----------------------------------------------
(element a (make sequence
  (p "style-p-style"  (style? (style)))
  (p "style-p-merge"  (style? (merge-style (style) (style))))
  (p "style-p-empty"  (style? (merge-style)))
  (p "style-p-no"     (style? "x"))
  (p "style-p-num"    (style? 42))))

; a merged style really applies, and the FIRST part wins a conflict
(element b (make paragraph
             use: (merge-style (style font-weight: 'bold)
                               (style font-weight: 'light font-posture: 'italic))
             (make sequence
               (p "merged-weight"  (if (equal? (inherited-font-weight) 'bold) "s:bold" "s:other"))
               (p "merged-posture" (if (equal? (inherited-font-posture) 'italic) "s:italic" "s:other")))))

; --- match-element? -------------------------------------------------------
(element c (make sequence
  (p "me-gi"      (match-element? "p" (probe)))
  (p "me-gi-up"   (match-element? "P" (probe)))
  (p "me-other"   (match-element? "sec" (probe)))
  (p "me-anc"     (match-element? (list "sec" "p") (probe)))
  (p "me-anc-no"  (match-element? (list "note" "p") (probe)))
  (p "me-true"    (match-element? #t (probe)))))

; --- inherited-element-attribute-string -----------------------------------
; `lang` sits on doc, chap and the probe paragraph itself; `role` only on chap
(element d (make sequence
  (p "ieas-self"  (inherited-element-attribute-string "p" "lang" (probe)))
  (p "ieas-chap"  (inherited-element-attribute-string "chap" "lang" (probe)))
  (p "ieas-doc"   (inherited-element-attribute-string "doc" "lang" (probe)))
  (p "ieas-role"  (inherited-element-attribute-string "chap" "role" (probe)))
  ; the GI matches but that element has no such attribute -> keep climbing,
  ; and there is no other `sec` above, so #f
  (p "ieas-nosec" (inherited-element-attribute-string "sec" "role" (probe)))
  (p "ieas-nogi"  (inherited-element-attribute-string "nosuch" "lang" (probe)))
  (p "ieas-noatt" (inherited-element-attribute-string "doc" "nosuch" (probe)))
  ; an EMPTY node-list is #f, not a diagnostic
  (p "ieas-empty" (inherited-element-attribute-string "doc" "lang" (empty-node-list)))
  ; for contrast, the un-narrowed sibling primitive
  (p "ias-lang"   (inherited-attribute-string "lang" (probe)))
  (p "ias-role"   (inherited-attribute-string "role" (probe)))))

; --- process-matching-children -------------------------------------------
; the chapter's children are a title, two sections and a note
(element e (process-matching-children "sec"))
(element f (process-matching-children "sec" "note"))
(element g (process-matching-children))
(element h (process-matching-children "nosuch"))

; --- process-first-descendant --------------------------------------------
(element i (process-first-descendant "p"))
(element j (process-first-descendant "note" "p"))
(element k (process-first-descendant))
(element l (process-first-descendant "nosuch"))
; the node itself is NOT among its descendants
(element m (process-first-descendant "m"))

; --- sosofo-label / sosofo-discard-labeled -------------------------------
; an unmatched label is a badConnection diagnostic and the content follows on
(element n (sosofo-label (literal "LABELED ") 'lab))
; *The case where discard-labeled actually SWALLOWS its label lives in
; proc2.scm, on the `-t fot` backend: the `-t sgml` TRANSFORM builder has no
; capture seam in this port, so a connected port's content leaks into the
; output stream instead of being buffered. That is a pre-existing gap in the
; connection machinery (it equally affects label: and content-map: on that
; backend), not something these primitives decide.
(element o (empty-sosofo))
; a label the discard does not name still follows on
(element q (sosofo-discard-labeled
             (make sequence (literal "KEPT2 ")
                            (sosofo-label (literal "OTHER ") 'nolab))
             'lab))
; the argument gates of both
(element r (p "sl-notsosofo" (sosofo-label "x" 'lab)))
(element s (p "sl-notsymbol" (sosofo-label (literal "x") "lab")))
(element t (p "sdl-notsosofo" (sosofo-discard-labeled "x" 'lab)))

(element title (empty-sosofo))
(element chap (process-children))
(element sec (process-children))
(element p (literal "[" (gi (current-node)) "]"))
(element note (literal "[NOTE]"))
(default (empty-sosofo))
