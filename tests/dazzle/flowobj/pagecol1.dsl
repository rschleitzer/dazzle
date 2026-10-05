<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; pagecol1 - the POSITIVE matrix of the PAGE/COLUMN MODEL: page-sequence and
; column-set-sequence, the last two flow object classes of the reference's
; registry (installFlowObjs, FlowObj.cxx:2996-2998).
;
; Both are plain compound brackets with NO ports. The whole contract is:
; page-sequence takes NO non-inherited characteristic at all - its six
; (page-category, force-last-page, force-first-page, first-page-type,
; justify-spread?, binding-edge) are INHERITED ones and arrive through the ics
; buffer - while column-set-sequence carries a bare display NIC and nothing
; else, exactly like aligned-column.

(root (make simple-page-sequence (process-children)))

(define (nonconst x) (if (string? x) 3pt 4pt))

(element p
  (make sequence

    ; --- page-sequence: no keywords of its own, six inherited ones ---------
    (make page-sequence (literal "ps-default"))
    (make page-sequence
      page-category: 'page
      force-last-page: 'front
      force-first-page: 'back
      first-page-type: 'right
      justify-spread?: #t
      binding-edge: 'right
      (literal "ps-full"))
    ; a #f boolean IC still prints - the ics buffer carries the value, not
    ; a specified/unspecified flag
    (make page-sequence
      justify-spread?: #f
      (literal "ps-false"))

    ; --- column-set-sequence: isDisplayNIC and nothing else ----------------
    (make column-set-sequence (literal "css-default"))
    (make column-set-sequence
      keep-with-previous?: #t
      keep-with-next?: #t
      may-violate-keep-before?: #t
      may-violate-keep-after?: #t
      position-preference: 'bottom
      keep: 'column-set
      break-before: 'page
      break-after: 'column
      space-before: 6pt
      space-after: 7pt
      (literal "css-full"))
    (make column-set-sequence
      space-before: (display-space 3pt min: 1pt max: 9pt)
      (literal "css-space"))

    ; a NON-CONSTANT characteristic value on each class: the lazy chain
    ; rather than the compile-time prototype. page-sequence has only
    ; inherited ones, so its lazy case is an IC.
    (make column-set-sequence
      space-before: (nonconst "s")
      (literal "css-lazy"))
    (make page-sequence
      binding-edge: (if (string? "x") 'left 'right)
      (literal "ps-lazy"))

    ; an unrelated INHERITED characteristic on both, to prove the ics buffer
    ; flushes into each class's own start tag
    (make page-sequence font-size: 11pt (literal "ps-ic"))
    (make column-set-sequence font-size: 12pt (literal "css-ic"))

    ; nesting: the model inside itself
    (make page-sequence
      (make column-set-sequence
        (make page-sequence (literal "nested"))))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
