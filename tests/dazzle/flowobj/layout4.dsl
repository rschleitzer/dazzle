<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; layout4 - the CAPTURE path: each of the five classes inside content that is
; recorded and replayed rather than emitted straight through (a
; simple-page-sequence header sosofo, a table-part header, and a math port).
; Every recorded call has to carry its NIC across the queue - the display
; half of included-container-area travels in its own slot, next to the
; class's own record.

(root (make simple-page-sequence
        left-header: (make side-by-side
                       keep: 'page
                       (make side-by-side-item
                         (make embedded-text direction: 'right-to-left
                           (literal "hdr-et"))))
        center-header: (make included-container-area
                         display?: #t
                         width: 4pt
                         escapement-direction: 'left-to-right
                         break-before-priority: 2
                         space-before: 5pt
                         (literal "hdr-ica"))
        right-header: (make aligned-column keep-with-next?: #t
                        (literal "hdr-ac"))
        (process-children)))

(element p
  (make sequence

    ; a math port: the six port-bearing math classes decompose through the
    ; same SaveFOTBuilder queue
    (make fraction
      (make side-by-side
        label: 'numerator
        (make side-by-side-item (literal "num")))
      (make included-container-area
        label: 'denominator
        scale: 3
        (literal "den")))

    ; a table-part header, the other capture site
    (make table
      (make table-part
        (make table-row
          label: 'header
          (make table-cell
            (make aligned-column space-after: 2pt (literal "th"))))
        (make table-row
          (make table-cell
            (make embedded-text direction: 'left-to-right
              (literal "td"))))))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
