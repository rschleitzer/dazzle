<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; math3 - the RTF backend's own math machinery: the three grid positioning
; modes, the grid separators and column alignment, math-display-mode (the
; \i\in of an inline math-operator), the sub/superscript heights and the
; over/under mark distances (all INHERITED characteristics, so they sit on a
; wrapping sequence), the EQ-field escaping, and the LAZY (non-constant)
; characteristic chain, which has to reach the same NICs the constant path
; bakes in.

; the RTF backend's own extension characteristics (dsssl/extensions.dsl)
(declare-characteristic superscript-height
  "UNREGISTERED::James Clark//Characteristic::superscript-height" 0pt)
(declare-characteristic subscript-depth
  "UNREGISTERED::James Clark//Characteristic::subscript-depth" 0pt)
(declare-characteristic over-mark-height
  "UNREGISTERED::James Clark//Characteristic::over-mark-height" 0pt)
(declare-characteristic under-mark-depth
  "UNREGISTERED::James Clark//Characteristic::under-mark-depth" 0pt)
(declare-characteristic grid-row-sep
  "UNREGISTERED::James Clark//Characteristic::grid-row-sep" 0pt)
(declare-characteristic grid-column-sep
  "UNREGISTERED::James Clark//Characteristic::grid-column-sep" 0pt)

(root (make simple-page-sequence (process-children)))

(define (n) 2)

(element p
  (make sequence

    ; row-major (the initial value): three cells into a 2-column grid
    (make grid grid-n-columns: 2
      (make grid-cell (literal "a"))
      (make grid-cell (literal "b"))
      (make grid-cell (literal "c")))

    ; column-major
    (make sequence grid-position-cell-type: 'column-major
      (make grid grid-n-columns: 2 grid-n-rows: 2
        (make grid-cell (literal "a"))
        (make grid-cell (literal "b"))
        (make grid-cell (literal "c"))))

    ; explicit - and a cell with no position at all, whose content the
    ; reference DISCARDS (a null curCellPtr extracts into a scratch string)
    (make sequence grid-position-cell-type: 'explicit
      (make grid grid-n-columns: 2 grid-n-rows: 2
        (make grid-cell column-number: 2 row-number: 1 (literal "x"))
        (make grid-cell column-number: 1 row-number: 2 (literal "y"))
        (make grid-cell (literal "dropped"))))

    ; the grid's own spacing and alignment
    (make sequence grid-column-sep: 6pt grid-row-sep: 3pt
      grid-column-alignment: 'end
      (make grid (make grid-cell (literal "q"))))

    ; an INLINE math-operator gets \\i\\in, a display one only \\i
    (make sequence math-display-mode: 'inline
      (make math-operator
        (literal "P")
        (make sequence label: 'operator (literal "op"))))

    ; the operator port's first character selects the RTF control word
    (make math-operator
      (make sequence label: 'operator (literal (string #\U-2211))))
    (make math-operator
      (make sequence label: 'operator (literal (string #\U-220F))))
    (make math-operator
      (make sequence label: 'operator (literal (string #\U-222B))))

    ; escaping inside an EQ field: the argument separator, the parentheses and
    ; the backslash all have to survive as data
    (make math-sequence (literal "a,b(c)d\\e;f"))

    ; ... but a fence's delimiters are written raw
    (make fence
      (make sequence label: 'open (literal "("))
      (make sequence label: 'close (literal ")")))

    ; the script/mark distances
    (make sequence superscript-height: 9pt subscript-depth: 4pt
      (make script
        (literal "S")
        (make sequence label: 'pre-sup (literal "1"))
        (make sequence label: 'pre-sub (literal "2"))
        (make sequence label: 'mid-sup (literal "5"))))
    (make sequence over-mark-height: 14pt under-mark-depth: 15pt
      (make mark
        (literal "M")
        (make sequence label: 'over-mark (literal "o"))
        (make sequence label: 'under-mark (literal "u"))))

    ; the LAZY chain: computed characteristic values
    (make grid grid-n-columns: (n) grid-n-rows: (+ (n) 1)
      (make grid-cell column-number: (n) (literal "L")))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
