<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; macro4 - the same feature on the `-t fot` backend (-2), where the two
; things the transform sink cannot show become visible: the
; startSequence/endSequence bracket MacroFlowObj::processInner wraps the
; body in, and the STYLE of the macro's own make (a macro takes the ordinary
; style path for every keyword that is not one of its characteristics).

(declare-flow-object-macro mac (a (b 3) #!contents c)
  (make paragraph
    (literal (string-append "a=" (if a a "#f") " b=" (number->string b)))
    c))

; an ATOMIC macro (no #!contents) - still a sequence bracket of its own
(declare-flow-object-macro atom (a)
  (literal (string-append "atom-" (if a a "#f"))))

(define st (style font-posture: 'italic))

(root (process-children))

(element doc
  (make sequence
    font-size: 12pt
    ; an inherited characteristic on the macro make: it lands on the
    ; macro's sequence, not on the paragraph the body builds
    (make mac a: "AY" font-weight: 'bold (literal "K"))
    ; use: chains a style object
    (make mac b: 7 use: st (literal "L"))
    (make atom a: "Z" font-size: 9pt)
    ; label: and content-map: are handled by the make, not by the macro -
    ; both diagnose here (there is no port for the label, and the content
    ; map is invalid), and both leave the flow object intact
    (make mac a: "lbl" label: 'mylabel (literal "M"))
    (make mac a: "cm" content-map: '(#\x) (literal "N"))
    ; a NON-CONSTANT characteristic value goes through the lazy chain
    (make mac a: (gi (current-node)) (literal "O"))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
