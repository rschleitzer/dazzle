<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; layout1 - the POSITIVE matrix of the LAYOUT-COMPOSITE family:
; embedded-text, included-container-area, side-by-side, side-by-side-item,
; aligned-column. All five are plain compound brackets - no ports, no serial
; decomposition - so the whole contract is: which characteristics each class
; takes, and how the fot backend prints them.

(root (make simple-page-sequence (process-children)))

(define (nonconst x) (if (string? x) 3pt 4pt))

(element p
  (make sequence

    ; --- embedded-text: ONE characteristic, an enum with two members -------
    (make embedded-text (literal "et-default"))
    (make embedded-text direction: 'left-to-right (literal "et-ltr"))
    (make embedded-text direction: 'right-to-left (literal "et-rtl"))

    ; --- aligned-column: isDisplayNIC and nothing else ---------------------
    (make aligned-column (literal "ac-default"))
    (make aligned-column
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
      (literal "ac-full"))

    ; --- side-by-side + side-by-side-item ----------------------------------
    ; the item class takes NO characteristics at all; the group takes the
    ; display NIC, and the three side-by-side-* INHERITED characteristics
    ; flush through the ics buffer of whatever flow object follows them.
    (make side-by-side (literal "sbs-empty"))
    (make side-by-side
      space-before: (display-space 3pt min: 1pt max: 9pt)
      keep: 'page
      (make side-by-side-item (literal "L"))
      (make side-by-side-item
        side-by-side-overlap-control: 'both
        side-by-side-pre-align: 'left
        side-by-side-post-align: 'right
        (literal "R")))

    ; --- included-container-area: the whole ten-key surface ----------------
    ; ITS SCALE DEFAULTS TO max-uniform, so even an untouched one prints an
    ; attribute; a numeric or paired scale switches to scale-x / scale-y.
    (make included-container-area (literal "ica-default"))
    (make included-container-area scale: 'max (literal "ica-max"))
    (make included-container-area scale: 2.5 (literal "ica-num"))
    (make included-container-area scale: '(1.5 3) (literal "ica-pair"))
    (make included-container-area
      width: #f height: #f (literal "ica-min"))
    (make included-container-area
      width: 10pt height: 20pt (literal "ica-explicit"))
    (make included-container-area
      display?: #t
      escapement-direction: 'bottom-to-top
      contents-rotation: 270
      position-point-x: 1pt
      position-point-y: -2pt
      break-before-priority: 5
      break-after-priority: -6
      keep-with-next?: #t
      space-after: 8pt
      (literal "ica-full"))

    ; a NON-CONSTANT characteristic value on each class that has one: the
    ; lazy chain, not the compile-time prototype.
    (make embedded-text
      direction: (if (string? "x") 'right-to-left 'left-to-right)
      (literal "et-lazy"))
    (make included-container-area
      width: (nonconst "s")
      contents-rotation: (+ 30 15)
      (literal "ica-lazy"))
    (make side-by-side
      space-before: (nonconst "s")
      (literal "sbs-lazy"))
    (make aligned-column
      break-after: (if (string? "x") 'column 'page)
      (literal "ac-lazy"))

    ; an INHERITED characteristic on each of the five, to prove the ics
    ; buffer flushes into the class's own start tag
    (make embedded-text font-size: 11pt (literal "et-ic"))
    (make included-container-area font-size: 12pt (literal "ica-ic"))
    (make side-by-side font-size: 13pt
      (make side-by-side-item font-size: 14pt (literal "sbs-ic")))
    (make aligned-column font-size: 15pt (literal "ac-ic"))

    ; nesting: the family inside itself
    (make side-by-side
      (make side-by-side-item
        (make aligned-column
          (make included-container-area
            (make embedded-text direction: 'left-to-right
              (literal "nested"))))))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
