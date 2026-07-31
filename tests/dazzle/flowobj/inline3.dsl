<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; inline3 (-t tex) - the three classes the TeX backend overrides, where the
; DERIVED character characteristics become visible: setCharacterNIC dumps
; thirteen \def's under `valid`, in an order of its own, and WITHOUT
; BreakAfterPriority (only the disabled #else branch of the reference has it).
;
; NOTE: `\def\Script` is written by POINTER ARITHMETIC in the reference
; (`nic.script+29`), stripping the 29 bytes "ISO/IEC 10179::1996//Script::"
; off the character property's public identifier - so a plain latin letter
; renders `{Latin}`. A character with NO script (and every character whose
; script property answers #f) makes the reference read from address 29 and
; SEGFAULT; this port renders an empty value there, and inline3b pins it.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence
    ; every field derived from the character properties of `A`
    (make character char: #\A)
    ; the same with three fields specified, and a stretch factor (MAYBESET:
    ; printed only when it differs from 1.0)
    (make character char: #\b math-class: 'operator space?: #t
      break-before-priority: 3 stretch-factor: 0.5)
    ; an explicit glyph-id: the TeX form prints the id plus "::<suffix>",
    ; and an id-less one prints EMPTY (where the fot dump prints "false")
    (make character char: #\c glyph-id: (glyph-id "public-id::7"))
    (make character char: #\d glyph-id: #f)
    ; an invalid char: leaves valid = 0, and then NOTHING is dumped except
    ; the \Character{} call itself
    (make character char: 5)
    ; the two other overridden classes
    (make alignment-point)
    (make sideline (literal "s"))
    ; and the three the TeX backend does NOT override: the plain FOTBuilder
    ; brackets (atomic / start-end) leave no TeX markup at all
    (make anchor)
    (make glyph-annotation (literal "g"))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
