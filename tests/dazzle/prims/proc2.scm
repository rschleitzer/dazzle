; proc2.scm - sosofo-discard-labeled where it actually discards, on the
; `-t fot` backend.
;
; *It needs a backend with a CAPTURE SEAM. The reference buffers a connected
; port's content into a SaveFOTBuilder on every backend; this port has that
; seam on the five styled backends (fot / rtf / tex / html / mif) but NOT on
; the `-t sgml` transform builder, where connected content still leaks into
; the output stream. proc1.scm carries the note; COMPLETENESS.md names the
; gap. Everything else about these two primitives - the argument gates, the
; badConnection diagnostic, an unmatched discard label - is
; backend-independent and pinned in proc1.
;
; ASCII ONLY, and MARKUP-FREE (see num1.scm).

(element doc (process-children))

; the labeled part vanishes, the rest stays
(element o (make paragraph
             (sosofo-discard-labeled
               (make sequence (literal "KEPT ")
                              (sosofo-label (literal "GONE ") 'lab))
               'lab)))
; two labels, only the named one goes
(element q (make paragraph
             (sosofo-discard-labeled
               (make sequence (literal "K1 ")
                              (sosofo-label (literal "G1 ") 'lab)
                              (literal "K2 ")
                              (sosofo-label (literal "K3 ") 'other))
               'lab)))
; nesting: the inner discard names a different label than the outer one
(element r (make paragraph
             (sosofo-discard-labeled
               (sosofo-discard-labeled
                 (make sequence (literal "N1 ")
                                (sosofo-label (literal "NG1 ") 'inner)
                                (sosofo-label (literal "NG2 ") 'outer))
                 'inner)
               'outer)))
; a discard whose label nothing carries changes nothing
(element s (make paragraph
             (sosofo-discard-labeled (literal "ALLKEPT ") 'nobody)))
(default (empty-sosofo))
