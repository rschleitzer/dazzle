<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; pagecol2 - the DIAGNOSTIC matrix of the page/column model: the unknown
; keyword message per class and a conversion failure per characteristic.
;
; It runs WITHOUT -2 on purpose, like layout2: under -2 the reference coerces
; a string value into a number/symbol/boolean before every characteristic
; conversion (Interpreter::convertFromString), which this port does not carry
; yet - a measured gap of the Convert layer, not of this family.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence

    ; page-sequence has no hasNonInheritedC at all, so EVERY non-inherited
    ; keyword is unknown - including the display keys its sibling accepts
    (make page-sequence display?: #t (literal "a"))
    (make page-sequence keep: 'page (literal "b"))
    (make page-sequence char: #\x (literal "c"))

    ; its six inherited characteristics, each with a bad value
    (make page-sequence page-category: 3pt (literal "d"))
    (make page-sequence force-last-page: "front" (literal "e"))
    (make page-sequence force-first-page: 42 (literal "f"))
    ; #t is a valid c-value symbol, so this one CONVERTS and prints "true"
    (make page-sequence first-page-type: #t (literal "g"))
    (make page-sequence justify-spread?: 'yes (literal "h"))
    (make page-sequence binding-edge: '(1 2) (literal "i"))

    ; column-set-sequence takes the display NIC and nothing else
    (make column-set-sequence display?: #t (literal "j"))
    (make column-set-sequence char: #\x (literal "k"))
    (make column-set-sequence width: 3pt (literal "l"))

    ; a conversion failure per display key - each leaves its field
    ; unspecified, so the dump stays silent
    (make column-set-sequence position-preference: 'page (literal "m"))
    (make column-set-sequence keep-with-previous?: 3pt (literal "n"))
    (make column-set-sequence keep-with-next?: 3pt (literal "o"))
    (make column-set-sequence keep: 'top (literal "p"))
    (make column-set-sequence break-before: 'top (literal "q"))
    (make column-set-sequence break-after: 'top (literal "r"))
    (make column-set-sequence may-violate-keep-before?: 3pt (literal "s"))
    (make column-set-sequence may-violate-keep-after?: 3pt (literal "t"))
    (make column-set-sequence space-before: 'top (literal "u"))
    (make column-set-sequence space-after: 'top (literal "v"))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
