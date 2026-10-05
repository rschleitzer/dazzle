<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; emph1 (-t fot) - `emphasizing-mark`, the one class of this family the
; reference binary CANNOT run: EmphasizingMarkFlowObj's copy constructor
; copies nic_ and forgets emphmark_ (style/EmphasizingMark.h:28), so every
; `make` of the class dereferences an indeterminate SosofoObj*. Measured on
; ALL SIX backends: rc 138/139, EXC_BAD_ACCESS inside
; EmphasizingMarkFlowObj::processInner - with and without a mark:.
;
; This golden is therefore OUR behaviour, built from what the class plainly
; intends and from the emission the reference's own backends are written for:
;   * the start tag is SELF-CLOSING and then closed by </emphasizing-mark>
;     (the same asymmetry glyph-annotation has, SgmlFOTBuilder.cxx:2140),
;   * the mark: sosofo is processed into the class's one port and replayed
;     inside <emphasizing-mark.mark> BEFORE the principal content
;     (SerialFOTBuilder::startEmphasizingMark / endEmphasizingMarkEM),
;   * an EMPTY mark renders no bracket at all (endAllEmphasizingMarkMark
;     checks the captured string),
;   * a mark whose own evaluation FAILS drops the whole make - the reference
;     does exactly that for the equivalent shape on a class it can run
;     (`left-header: (make sequence)` on a simple-page-sequence: a contentless
;     compound in a NIC has no processing mode, and the failing chain takes the
;     flow object with it, measured), and
;   * anchors are suppressed while the mark renders, so the pending <a name>
;     of the current element appears with the principal content.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence
    (make emphasizing-mark break-before-priority: 1 mark: (make character char: #\C)
      (literal "m"))
    ; no mark at all
    (make emphasizing-mark (literal "n"))
    ; a compound mark, a display content, and the second priority
    (make emphasizing-mark break-after-priority: 2
      mark: (make sequence (literal "M") (make alignment-point))
      (make paragraph (literal "q")))
    ; a mark that produces NOTHING leaves the bracket out
    (make emphasizing-mark mark: (empty-sosofo) (literal "r"))
    ; a mark whose evaluation fails takes the whole make with it (no output,
    ; one diagnostic)
    (make emphasizing-mark mark: (make sequence) (literal "r2"))
    ; an invalid mark: is a rejected characteristic value
    (make emphasizing-mark mark: 5 (literal "s"))
    ; not a keyword of the class
    (make emphasizing-mark bogus: 5 (literal "t"))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
