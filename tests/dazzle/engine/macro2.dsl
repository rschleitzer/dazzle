<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; macro2 - the diagnostics of a MALFORMED declaration and of a malformed
; `make` of a macro (-2). The declarations here are ordered so that the one
; whose recovery swallows the rest of the entity (macro3) is not among them.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(define (out s) (make fi data: s))

; --- a bad token in the characteristic list -------------------------------
(declare-flow-object-macro badlist (42)
  (out "x"))

; --- nothing may follow #!contents: `missing closing parenthesis`, and the
;     leftover body then reads as a top-level form of its own -------------
(declare-flow-object-macro afterc (#!contents c a)
  (out "x"))

; --- an unknown #! named constant -----------------------------------------
(declare-flow-object-macro badhash (#!bogus c)
  (out "x"))

; --- an EMPTY body (parseBegin reads the first expression without
;     allowCloseParen in both modes - see query4) ----------------------
(declare-flow-object-macro nobody ())

; --- a body that is not a sosofo: the CheckSosofoInsn behind the body,
;     reported once per make, and the rule falls back to process-children --
(declare-flow-object-macro notsosofo ()
  42)

; --- an ATOMIC macro (no #!contents) ---------------------------------------
(declare-flow-object-macro atomic (a)
  (out "atomic"))

; --- a well-formed macro, for the make diagnostics ------------------------
(declare-flow-object-macro good (a #!contents c)
  (make sequence (out (if a a "#f")) c))

(root (process-children))

(element doc
  (make sequence
    (out "[")
    ; a keyword that is neither a characteristic of the macro nor an
    ; inherited characteristic
    (make good bogus: "b" (out "K"))
    ; content given to an atomic macro
    (make atomic a: "A" (out "unwanted"))
    ; the malformed declarations left these names unbound
    (make badlist)
    (make badhash)
    (make nobody)
    (out "]")
    (process-children)))

; the macro body is not a sosofo: once per matched element, and the rule
; falls back to process-children (so the section's text still appears)
(element sec (make notsosofo))

; a non-sosofo CONTENT expression of an ordinary make - the whole flow object
; is dropped and this rule too falls back to process-children
(element note (make sequence (out "before") 42 (out "after")))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
