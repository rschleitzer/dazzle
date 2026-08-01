<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; layout2 - the DIAGNOSTIC matrix of the LAYOUT-COMPOSITE family: one
; conversion failure per characteristic, the unknown-keyword message per
; class, and the two asymmetries worth pinning - #f is a VALID width/height
; (the minimum form) but an INVALID direction, because embedded-text's
; allowed set deliberately leaves symbolFalse out.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence

    ; embedded-text: the enum takes exactly two members - #f, a foreign
    ; symbol and a non-symbol all fail, and the field stays unset.
    (make embedded-text direction: #f)
    (make embedded-text direction: 'inside)
    (make embedded-text direction: "left-to-right")

    ; included-container-area: one failure per key. *width:/height: #f is
    ; NOT a failure - it selects the minimum form (see layout1).
    (make included-container-area display?: 'yes)
    (make included-container-area scale: "big")
    (make included-container-area scale: 'inside)
    (make included-container-area scale: '(1))
    (make included-container-area scale: '(1 2 3))
    (make included-container-area width: 'wide)
    (make included-container-area height: 'tall)
    (make included-container-area position-point-x: 'here)
    (make included-container-area position-point-y: 'there)
    (make included-container-area escapement-direction: 'sideways)
    (make included-container-area contents-rotation: 90pt)
    (make included-container-area break-before-priority: "5")
    (make included-container-area break-after-priority: #t)

    ; the display NIC on the two classes that take one
    (make side-by-side keep: 'sometimes)
    (make aligned-column position-preference: 'middle)

    ; the unknown-keyword message: a key the class does not take, once per
    ; class - including the two that take a display NIC (so a NON display
    ; key is unknown there) and the item class, which takes NOTHING at all.
    (make embedded-text width: 3pt)
    (make included-container-area direction: 'left-to-right)
    (make side-by-side direction: 'left-to-right)
    (make aligned-column contents-rotation: 90)
    (make side-by-side-item space-before: 3pt)
    (make side-by-side-item direction: 'left-to-right)

    ; an inherited characteristic whose VALUE is invalid, on the class whose
    ; three ICs are the family's own
    (make side-by-side side-by-side-overlap-control: 'suppress-left
      (make side-by-side-item side-by-side-pre-align: 3pt))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
