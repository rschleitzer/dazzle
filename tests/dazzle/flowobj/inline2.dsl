<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; inline2 (-2) - the DIAGNOSTIC side of the inline/mark family, plus the one
; characteristic name that is no syntactic key at all.

; declare-char-characteristic+property registers a CHAR NIC: a non-inherited
; characteristic of the `character` flow object AND a character property of
; that name. NOTE: as a characteristic it is ACCEPTED and then DROPPED without
; a word - CharacterFlowObj::setNonInheritedC returns on the charNICDefined
; arm before its CANNOT_HAPPEN, so no value of it ever reaches a backend.
(declare-char-characteristic+property my-cc
  "UNREGISTERED::me//Characteristic::my-cc" #f)

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence

    ; a declared char NIC: no diagnostic, no output
    (make character char: #\A my-cc: 5)

    ; every conversion failure of the class, one per characteristic. Each
    ; leaves its field UNSPECIFIED, so the dump stays silent about it - and
    ; `char:` failing also means the derivation never runs.
    (make character char: 5)
    (make character char: #\A glyph-id: "not-a-glyph-id")
    (make character char: #\A script: 5)
    (make character char: #\A math-class: 'bogus)
    (make character char: #\A math-font-posture: 'bogus)
    (make character char: #\A stretch-factor: "x")
    (make character char: #\A break-before-priority: "x")
    (make character char: #\A space?: 5)

    ; a one-character STRING is a valid char: (convertCharC's second arm)
    (make character char: "Z")

    ; not a keyword of this class at all
    (make character bogus: 5)
    (make anchor bogus: 5)
    (make glyph-annotation bogus: 5)

    ; content on the two ATOMIC classes (character and alignment-point derive
    ; from FlowObj, not CompoundFlowObj)
    (make character char: #\A (literal "x"))
    (make alignment-point (literal "x"))

    ; the anchor's own conversion failures
    (make anchor display?: 5 break-after-priority: "x")))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
