<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; trans2 - the STYLE SEAM of the transform backend. The reference pushes the
; attached style for every flow object on every backend (FlowObj::process),
; and the transform builder's setters are simply the no-op base. So nothing
; reaches the output - but a LAZY characteristic still evaluates, and its
; failure is still reported. A backend that skipped the style push would
; stay silent here.

(declare-flow-object-class element
  "UNREGISTERED::James Clark//Flow Object Class::element")

(define (bomb) (car '()))

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence

    ; a lazy inherited characteristic that errors when the stack pushes it
    (make sequence font-size: (bomb) (literal "a"))
    (literal "|")

    ; the same on one of the transform backend's OWN classes
    (make element gi: "x" font-size: (bomb) (literal "b"))
    (literal "|")

    ; a lazy characteristic on a flow object with NO content at all
    (make sequence font-posture: (bomb))
    (literal "|")

    ; an inherited characteristic of the wrong type (converted at make time)
    (make sequence font-size: "notalength" (literal "c"))
    (literal "|")

    ; a non-inherited characteristic conversion failure
    (make rule line-thickness: "bogus")
    (literal "|")

    ; a style object applied through use:
    (make sequence use: (style font-size: (bomb)) (literal "d"))
    (literal "|")

    ; actual-* dependency resolution: the outer value the inner asks for
    (make sequence font-size: 12pt
      (make sequence font-size: (* 2 (actual-font-size)) (literal "e")))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
