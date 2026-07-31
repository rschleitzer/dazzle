<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; math2 - the DIAGNOSTIC matrix of the MATH family: one conversion failure per
; characteristic, the positivity gate of the two grid classes, the
; isCharacter demand of radical:, and the unknown-keyword message per class.
; Every rejected value leaves its field unspecified, so the dump stays silent
; about it.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence

    ; radical: must be a sosofo that answers isCharacter - a non-sosofo, a
    ; sosofo of the wrong class, and #f all fail.
    (make radical radical: 3)
    (make radical radical: (make sequence))
    (make radical radical: #f)

    ; grid: convertIntegerC, then `<= 0` with the SAME diagnostic
    (make grid grid-n-columns: "two")
    (make grid grid-n-columns: 0)
    (make grid grid-n-rows: -1)

    ; grid-cell: likewise, on both of its counts
    (make grid grid-n-columns: 1
      (make grid-cell column-number: #t)
      (make grid-cell column-number: 0)
      (make grid-cell row-number: -3))

    ; the unknown-keyword message, once per class that HAS keywords and once
    ; for a class that has none at all
    (make radical grid-n-rows: 2)
    (make grid radical: (make character char: #\R))
    (make grid-cell grid-n-columns: 2)
    (make math-sequence char: #\A)
    (make fraction glyph-id: (glyph-id "p::1"))
    (make script mark: (make sequence))
    (make superscript row-number: 1)))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
