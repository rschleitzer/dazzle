<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; inline5 (-t sgml) - the family on the TRANSFORM backend, which overrides
; none of it either: the character's char is written into the output STREAM as
; text (the base `character` again), the anchor swallows its content, and the
; three compounds are pure pass-throughs. That makes this the one golden where
; the family's output is plain document text.
;
; The characters stay inside the 8-bit range on purpose: above it the
; reference's output encoder falls back to numeric character references,
; which is the still-open OutputEncoder item and has
; nothing to do with this family.

(root (make sequence (process-children)))

(element p
  (make sequence
    (make character char: #\A)
    (literal "|")
    (make character char: 5)
    (make character)
    (make alignment-point)
    (make anchor (literal "dropped"))
    (make sideline (literal "s"))
    (make glyph-annotation (make character char: #\g))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
