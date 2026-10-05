<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; inline4 (-t rtf) - the family on a backend that overrides NONE of it, so the
; plain FOTBuilder brackets decide everything. NOTE: the base `character`
; EMITS THE CHARACTER AS TEXT when the NIC is valid (FOTBuilder.cxx:174) and
; only then takes the atomic bracket, so the RTF stream carries "A" - while
; every characteristic of the make is invisible. The anchor is atomic and
; DISCARDS its content, sideline and glyph-annotation are transparent
; brackets, and an invalid char: (valid = 0) emits nothing at all.
;
; The same file is the html/mif behaviour by construction: those two backends
; do not override the family either.

(root (make simple-page-sequence (process-children)))

(element p
  (make paragraph
    (make character char: #\A)
    (make character char: #\B math-class: 'binary stretch-factor: 2.5)
    (make character char: 5)
    (make character)
    (make alignment-point)
    (make anchor (literal "dropped"))
    (make sideline (literal "s"))
    (make glyph-annotation break-after-priority: 4 (literal "g"))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
