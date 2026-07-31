<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; online1b - ★OUR behaviour. A multi-mode inside another multi-mode's NAMED
; MODE crashes the reference binary: SerialFOTBuilder keeps ONE save_ list
; for every open multi-mode (FOTBuilder.cxx:3335), so the inner class inserts
; its port queues into the same list and consumes them again during the
; outer's replay - by the time the outer's endMultiMode runs, save_.get()
; hands back a dangling head and `mode->emit(*this)` reads address 0x8.
; Measured rc 139, EXC_BAD_ACCESS in SerialFOTBuilder::endMultiMode
; (lldb backtrace, frame 1 = MultiModeFlowObj::processInner of the OUTER
; multi-mode). Nesting inside the PRINCIPAL stream is fine and lives in
; online1.
;
; This port decomposes the ports per flow object, so each multi-mode owns its
; own queues and the nesting simply works. The golden is the emission the
; reference's own SgmlFOTBuilder code is written for.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence
    (make multi-mode multi-modes: '(#f outer)
      (literal "OP")
      (make multi-mode label: 'outer multi-modes: '(#f inner)
        (literal "IP")
        (make sequence label: 'inner (literal "IN"))))

    ; the same shape one level deeper, and with the outer mode NAMED only
    (make multi-mode multi-modes: '(a)
      (make multi-mode label: 'a multi-modes: '(b)
        (make sequence label: 'b (literal "deep"))))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
