<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; pagecol4 - the CAPTURE path: both classes inside content that is recorded
; and replayed instead of emitted straight through (a simple-page-sequence
; header sosofo, a math port and a table-part header). page-sequence records
; a payload-less bracket, column-set-sequence has to carry its display NIC
; across the queue.

(root (make simple-page-sequence
        left-header: (make page-sequence
                       binding-edge: 'left
                       (literal "hdr-ps"))
        center-header: (make column-set-sequence
                         keep: 'page
                         space-before: 5pt
                         (literal "hdr-css"))
        (process-children)))

(element p
  (make sequence

    ; a math port: the six port-bearing math classes decompose through the
    ; same SaveFOTBuilder queue
    (make fraction
      (make page-sequence
        label: 'numerator
        (literal "num"))
      (make column-set-sequence
        label: 'denominator
        break-after: 'column
        (literal "den")))

    ; a table-part header, the other capture site
    (make table
      (make table-part
        (make table-row
          label: 'header
          (make table-cell
            (make column-set-sequence space-after: 2pt (literal "th"))))
        (make table-row
          (make table-cell
            (make page-sequence page-category: 'page (literal "td"))))))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
