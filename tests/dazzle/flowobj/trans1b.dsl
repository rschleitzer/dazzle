<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; trans1b - *OUR behaviour. `emphasizing-mark` on the transform backend is the
; one member of the port families that the reference binary cannot survive:
; SerialFOTBuilder::endEmphasizingMarkEM (FOTBuilder.cxx:2771) pops the mark
; port's SaveFOTBuilder off the shared save_ list with save_.get() and emits
; it, but endEmphasizingMark then runs endEmphasizingMarkSerial over a list
; that no longer owns it. Alone the reference already loses the whole flow
; object (rc 0, EMPTY output where the text should be); with a sibling after
; it, it SEGFAULTS (rc 139) - the same defect family as the endMultiMode
; crash pinned in online1b.
;
; This port emits the mark content followed by the principal content, which is
; what the reference's own bracket order prescribes.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence
    (make emphasizing-mark
      mark: (make sequence (literal "em"))
      (literal "principal"))
    (literal "|tail")))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
