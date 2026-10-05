<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; macro3 - the DUPLICATE gate of declare-flow-object-macro, plus the one
; malformed declaration whose recovery swallows the rest of the entity (-2).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(define (out s) (make fi data: s))

; --- the gate reads the INHERITED-CHARACTERISTIC definition record --------
; There is no flow-object definition record in the reference at all: the
; test is `ident->inheritedCDefined(part, loc) && part <= currentPartIndex()`,
; which only a declare-characteristic in this part ever satisfies. So a name
; already declared as a characteristic is refused - as a macro AND as a
; flow object class - with the characteristic's location as the auxiliary
; line, while two declarations of the same MACRO name simply overwrite (see
; macro1's `again`).
(declare-characteristic mychar
  "UNREGISTERED::James Clark//Characteristic::nonesuch" #f)
(declare-flow-object-macro mychar ()
  (out "macro-mychar"))
(declare-flow-object-class mychar
  "UNREGISTERED::James Clark//Flow Object Class::element")

; --- a BUILT-IN characteristic name is NOT refused ------------------------
; its prototype carries part -1, so `part <= currentPartIndex()` is false.
(declare-flow-object-macro font-size ()
  (out "macro-font-size"))

(root
  (make sequence
    (make font-size)
    ; mychar was never bound to anything
    (make mychar)))

; --- the characteristic list is NOT optional ------------------------------
; `(out` is read as the list, `out` as a characteristic name, and the string
; that follows is `unexpected token """`. From there the top-level loop
; reads on TOKEN BY TOKEN (it never skips a failed form - see query5), so
; the opening quote of that string starts a string that runs to the end of
; the entity: everything below this line is consumed. That is why this form
; is in a fixture of its own.
(declare-flow-object-macro nolist
  (out "x"))

(element doc (out "never-reached"))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
