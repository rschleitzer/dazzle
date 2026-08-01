<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; trans1 - the PORT ORDER of the transform backend. Every multi-port class is
; written with its labelled children BEFORE the unlabelled content, so a port
; machinery that really decomposes puts the principal content first and the
; ports in PORT-DECLARATION order, while a replay in source order does not.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence

    ; script: six ports, declared back to front
    (make script
      (make sequence label: 'mid-sub (literal "6"))
      (make sequence label: 'mid-sup (literal "5"))
      (make sequence label: 'post-sub (literal "4"))
      (make sequence label: 'post-sup (literal "3"))
      (make sequence label: 'pre-sub (literal "2"))
      (make sequence label: 'pre-sup (literal "1"))
      (literal "S"))
    (literal "|")

    ; fraction has NO principal port: the unlabelled content is the bar area
    (make fraction
      (make sequence label: 'denominator (literal "D"))
      (make sequence label: 'numerator (literal "N"))
      (literal "loose"))
    (literal "|")

    (make mark
      (make sequence label: 'under-mark (literal "u"))
      (make sequence label: 'over-mark (literal "o"))
      (literal "M"))
    (literal "|")

    (make fence
      (make sequence label: 'close (literal "]"))
      (make sequence label: 'open (literal "["))
      (literal "F"))
    (literal "|")

    (make radical
      (make sequence label: 'degree (literal "3"))
      (literal "body"))
    (literal "|")

    (make math-operator
      (make sequence label: 'upper-limit (literal "up"))
      (make sequence label: 'lower-limit (literal "lo"))
      (make sequence label: 'operator (literal "op"))
      (literal "P"))
    (literal "|")

    ; emphasizing-mark is NOT here - it crashes the reference on this
    ; backend; see trans1b.

    ; the multi-mode ports replay in the order of the multi-modes: list, not
    ; in source order
    (make multi-mode
      multi-modes: (list (list 'b "second") (list 'a "first"))
      (make sequence label: 'a (literal "A"))
      (make sequence label: 'b (literal "B"))
      (literal "principal"))
    (literal "|")

    ; a table: the serial decomposition on the transform sink
    (make table
      (make table-row
        (make table-cell (literal "c1"))
        (make table-cell (literal "c2")))
      (make table-row
        (make table-cell (literal "c3"))))
    (literal "|")

    ; a label with no port at all still messages, on this backend too
    (make sequence
      (make sequence label: 'nosuchport (literal "orphan"))
      (literal "tail"))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
