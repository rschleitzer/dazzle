<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; conv2 - the same `-2` string leniency (conv1) on the NON-INHERITED side:
; every family whose setNonInheritedC runs its own converters. conv1 covers
; the conversion KINDS through inherited characteristics and the shared
; display NIC; this one covers the per-class NIC records, where the
; reference calls the very same convert*C functions.
;
; Run twice as well: conv2 (-2) and conv2b (no flag, every value invalid).
;
; *The leniency of the symbol half is only as wide as the SYMBOL TABLE: it
; LOOKS a symbol up and takes it only if it carries a c-value, so
; `direction: "left-to-right"`, `math-class: "binary"` and `quadding:
; "center"` (conv1) convert while `scale: "max-uniform"` does NOT - that
; name is interned by nothing in this engine, and a string that names no
; existing symbol stays a string. Measured, and identical on both sides.

(element a
  ; the two repros that MEASURED the gap: a symbol
  ; through an enum NIC, an integer through a priority NIC, plus the rest of
  ; the layout-composite record - lengths, a boolean and the scale enum
  (make sequence
    (make embedded-text direction: "left-to-right")
    (make included-container-area break-before-priority: "5"
                                  break-after-priority: "-2"
                                  width: "3pt" height: "4pt"
                                  display?: "yes" scale: "max-uniform"
                                  contents-rotation: "90")
    (make included-container-area scale: "2.5"
                                  contents-rotation: "45pt")))

(element b
  ; the CHARACTER NIC: its own converters, one per kind - a char, a real, an
  ; integer pair, the two enum sets with their allowed values, and the seven
  ; booleans of the char-property half
  (make sequence
    (make character char: #\A
                    stretch-factor: "1.5"
                    break-before-priority: "6" break-after-priority: "7"
                    math-class: "binary" math-font-posture: "italic"
                    punct?: "yes" space?: "no" record-end?: "true"
                    input-tab?: "false" input-whitespace?: "yes"
                    drop-after-line-break?: "yes"
                    drop-unless-before-line-break?: "no")
    ; and the rejections: an out-of-set symbol, a non-number, a real where an
    ; integer is wanted
    (make character char: #\B
                    math-class: "italic" stretch-factor: "wide"
                    break-before-priority: "1.5")))

(element c
  ; the RULE NIC (its own length + orientation + priorities) and the
  ; table-column NIC, whose width takes the TableLengthSpec route: the
  ; lengthSpec branch first, then convertLengthSpecC
  (make sequence
    (make rule orientation: "vertical" length: "18pt"
               break-before-priority: "2" break-after-priority: "3")
    (make table
      (make table-column width: "40pt" column-number: "1" n-columns-spanned: "1")
      (make table-row
        (make table-cell n-columns-spanned: "1" n-rows-spanned: "1"
                         cell-before-row-margin: "2pt"
                         starts-row?: "yes" ends-row?: "no"
          (literal "cell"))))))

(element d
  ; the box/score/line NICs of the inline families, and the paragraph-break
  ; integer NIC
  (make sequence
    (make score type: "through" (literal "score"))
    (make box display?: "no" box-type: "border" box-open-end?: "yes"
              (literal "box"))
    (make leader length: "30pt" (literal "lead"))
    (make paragraph-break)))

(element e
  ; the page/column model and the simple-page-sequence NIC, whose
  ; characteristics are inherited ones reaching the backend through the ics
  ; buffer - the same converters, a different carrier
  (make sequence
    (make column-set-sequence space-before: "9pt" break-before: "page"
      (literal "csq"))
    (make page-sequence page-category: "body"
                        first-page-type: "true"
                        justify-spread?: "no"
                        binding-edge: "left"
      (literal "pseq"))))

]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
