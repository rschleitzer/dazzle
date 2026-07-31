<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; math4 - the same matrix as math1, on the TRANSFORM backend (-t sgml), where
; every math bracket is a no-op and only the document text survives.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence

    ; the four port-less brackets
    (make math-sequence (literal "ms"))
    (make unmath (literal "um"))
    (make superscript (literal "sup"))
    (make subscript (literal "sub"))

    ; fraction: the bar comes first, then the unlabelled content (fraction has
    ; NO principal port), then the two ports in declaration order.
    (make fraction
      (literal "loose")
      (make sequence label: 'numerator (literal "N"))
      (make sequence label: 'denominator (literal "D")))

    ; a fraction whose bar carries a style through the fraction-bar
    ; characteristic
    (make fraction
      fraction-bar: (make rule line-thickness: 2pt)
      (make sequence label: 'numerator (literal "n2"))
      (make sequence label: 'denominator (literal "d2")))

    ; script: the principal content plus all six ports
    (make script
      (literal "S")
      (make sequence label: 'pre-sup (literal "1"))
      (make sequence label: 'pre-sub (literal "2"))
      (make sequence label: 'post-sup (literal "3"))
      (make sequence label: 'post-sub (literal "4"))
      (make sequence label: 'mid-sup (literal "5"))
      (make sequence label: 'mid-sub (literal "6")))

    ; script with only some ports connected
    (make script
      (literal "s2")
      (make sequence label: 'post-sup (literal "x")))

    (make mark
      (literal "M")
      (make sequence label: 'over-mark (literal "o"))
      (make sequence label: 'under-mark (literal "u")))

    (make fence
      (literal "F")
      (make sequence label: 'open (literal "["))
      (make sequence label: 'close (literal "]")))

    ; radical with a character radical: - the CharacterNIC is extracted, not
    ; processed
    (make radical
      radical: (make character char: #\R)
      (literal "body")
      (make sequence label: 'degree (literal "3")))

    ; radical without one: radicalRadicalDefaulted
    (make radical
      (literal "b2")
      (make sequence label: 'degree (literal "4")))

    (make math-operator
      (literal "P")
      (make sequence label: 'operator (literal "op"))
      (make sequence label: 'lower-limit (literal "lo"))
      (make sequence label: 'upper-limit (literal "up")))

    ; grid / grid-cell: both counts, one count, no count
    (make grid
      grid-n-columns: 2
      grid-n-rows: 3
      (make grid-cell column-number: 1 row-number: 1 (literal "c11"))
      (make grid-cell column-number: 2 (literal "c2"))
      (make grid-cell row-number: 2 (literal "r2"))
      (make grid-cell (literal "plain")))

    (make grid (literal "bare"))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
