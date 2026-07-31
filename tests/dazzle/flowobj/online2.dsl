<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; online2 - the DIAGNOSTIC matrix of the ONLINE family. `multi-modes:` is the
; one characteristic, and every member of its list has to be one of four
; shapes: #f, a symbol, (#f "desc") or (sym "desc"). ★The FIRST member that
; is none of them messages and STOPS - the prefix already collected stays,
; which is why the dump still shows the modes that came before it.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence

    ; not a list at all
    (make multi-mode multi-modes: 'a)
    (make multi-mode multi-modes: 3)
    (make multi-mode multi-modes: #f)

    ; an improper list: the members before the bad tail are kept
    (make multi-mode multi-modes: '(a b . c) (literal "improper"))

    ; a member of the wrong type - and the members BEFORE it survive
    (make multi-mode multi-modes: '(a 3 b) (literal "badmember"))

    ; the two-element form, malformed in each of its three ways
    (make multi-mode multi-modes: (list (list 'x)))
    (make multi-mode multi-modes: (list (list 'x "d" "e")))
    (make multi-mode multi-modes: (list (list 'x 3)))
    (make multi-mode multi-modes: (list (list 3 "d")))

    ; the unknown-keyword message: marginalia takes NO characteristic at all
    ; (its four are inherited ones), multi-mode takes exactly one
    (make marginalia multi-modes: '(a))
    (make marginalia space-before: 3pt)
    (make multi-mode direction: 'left-to-right)
    (make multi-mode space-before: 3pt)

    ; a label that names no mode of the enclosing multi-mode
    (make multi-mode multi-modes: '(a)
      (make sequence label: 'nosuch (literal "N")))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
