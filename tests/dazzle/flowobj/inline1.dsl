<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; inline1 - the POSITIVE matrix of the inline/mark flow object family on the
; `-t fot` backend: character (every one of its fifteen keyed
; characteristics), alignment-point, sideline, anchor and glyph-annotation.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence

    ; the bare character: `char:` alone, and every other field DERIVED from
    ; that character's properties (invisible in the dump - only specified
    ; fields print - but visible in the tex golden).
    (make character char: #\A)

    ; every keyed characteristic at once, in the reference's dump order
    (make character
      char: #\B
      glyph-id: (glyph-id "public-id::34")
      space?: #t
      record-end?: #t
      input-tab?: #t
      input-whitespace?: #t
      punct?: #t
      drop-after-line-break?: #t
      drop-unless-before-line-break?: #t
      script: "ISO/IEC 10036/RA::Latin"
      math-class: 'binary
      math-font-posture: 'italic
      break-before-priority: 7
      break-after-priority: 8
      stretch-factor: 2.5)

    ; the three values that print a WORD rather than a value: an id-less
    ; glyph-id and a #f script both render "false", and math-font-posture: #f
    ; is IN its allowed set (unlike math-class:).
    (make character char: #\C glyph-id: #f script: #f math-font-posture: #f)

    ; no char at all: valid stays 0, and the dump prints an EMPTY start tag
    ; (still split across the record end - `<character` RE `/>`).
    (make character)

    ; a character carrying an inherited characteristic, so the ics buffer
    ; flushes into its start tag
    (make character char: #\D font-size: 20pt)

    ; the two NIC-less classes
    (make alignment-point)
    (make sideline (literal "s"))
    (make sideline (make paragraph (literal "p")))

    ; the anchor: atomic output, inline priorities, display? flag - and
    ; NOTE: CONTENT, which the class accepts (it is a CompoundFlowObj) and then
    ; DISCARDS, because processInner never calls the base.
    (make anchor)
    (make anchor display?: #t break-before-priority: 3 break-after-priority: 4)
    (make anchor (literal "dropped"))

    ; glyph-annotation: a compound whose start tag is SELF-CLOSING and is then
    ; closed by </glyph-annotation> - the reference's own asymmetry.
    (make glyph-annotation (literal "g"))
    (make glyph-annotation break-before-priority: 1 break-after-priority: 2
      (make character char: #\E)
      (make alignment-point))

    ; the LAZY chain: a non-constant characteristic value is compiled and
    ; evaluated per make instead of folded into the prototype.
    (make character char: (if #t #\F #\G) break-after-priority: (+ 1 2))
    (make anchor display?: (if #t #t #f) break-before-priority: (* 2 3))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
