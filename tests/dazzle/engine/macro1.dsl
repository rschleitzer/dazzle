<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; macro1 - declare-flow-object-macro, the positive matrix (-2; the form is a
; keys2[] entry, so it needs the flag - macro1b is the same file without it).
;
; A macro flow object (style/MacroFlowObj.cxx) is no backend class at all:
; `make NAME` binds the declared characteristics as frame variables - each
; either from the make's keyword, or from the declared default, or #f - plus,
; with #!contents, the content sosofo, and evaluates the declaration's BODY.
; The resulting sosofo is processed inside a startSequence/endSequence
; bracket (invisible on the transform backend; macro4 pins it under -t fot).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (yn b) (if b "yes" "no"))

; --- no characteristics, no contents: an ATOMIC macro --------------------
(declare-flow-object-macro plain ()
  (out "plain"))

; --- characteristics: given / defaulted / undeclared-default (#f) --------
; the default of `b` reads `a`, the characteristic declared before it.
(declare-flow-object-macro chars (a (b (string-append "b-of-" (if a a "none"))) #!contents c)
  (make sequence
    (out (string-append "a=" (if a a "#f")))
    (out (string-append "b=" b))
    c))

; --- the contents variable used TWICE and not at all ---------------------
(declare-flow-object-macro twice (#!contents c)
  (make sequence c (out "-between-") c))
(declare-flow-object-macro drop (#!contents c)
  (out "content-dropped"))

; --- the body sees the current node and the current processing mode ------
(declare-flow-object-macro whereami ()
  (out (string-append "gi=" (gi (current-node)))))

; --- a characteristic may be a SOSOFO, and may shadow an inherited
;     characteristic name and a make keyword name -----------------------
(declare-flow-object-macro shadow (font-size (label "lab") #!contents c)
  (make sequence
    (out (string-append "font-size=" (if font-size font-size "#f")))
    (out (string-append "label=" label))
    c))

; --- nesting: a macro body making another macro --------------------------
(declare-flow-object-macro outer (#!contents c)
  (make chars a: "from-outer" c))

; --- redefinition: the LAST declaration of a name wins (the reference has
;     no flow-object duplicate record, only the characteristic one) -------
(declare-flow-object-macro again ()
  (out "again-first"))
(declare-flow-object-macro again ()
  (out "again-second"))

(root (process-children))

(element doc
  (make sequence
    (make plain)
    (make chars a: "AY" (out "content-of-chars"))
    (make chars b: "BEE" (out "content-of-chars-2"))
    ; a NON-CONSTANT characteristic value: the lazy chain, evaluated per make
    (make chars a: (gi (current-node)) (out "content-of-chars-3"))
    (make twice (out "T"))
    (make drop (out "never"))
    (make whereami)
    (make shadow font-size: "12pt" (out "shadow-content"))
    (make outer (out "outer-content"))
    (make again)
    (out "done")
    (process-children)))

; --- a compound macro with NO content defaults to (process-children) ------
(element sec (make chars a: "in-sec"))

; --- inside a macro body the current node is still the matched element ----
(element note (make whereami))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
