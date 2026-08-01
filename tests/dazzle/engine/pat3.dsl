<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; pat3 - every DIAGNOSTIC of Interpreter::convertToPattern, under -2, one
; malformed pattern per construction rule. A bad pattern is reported where
; the rule stands and the rule is dropped; the body is consumed either way,
; so every later rule still parses and the surviving ones still fire.
;
; *What this pins: which shape produces which of the eight messages -
; patternEmptyGi, patternNotList, patternBadGi, patternBadMember,
; patternMissingQualifierValue, patternUnknownQualifier,
; patternBadQualifierValue, patternBadAttributeQualifier and
; patternChildRepeat - and that `repeat:` is an error only INSIDE a
; children: list.
;
; A MARKED SECTION, not a SYSTEM .scm entity (see key1.dsl).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

(root (process-children))
(element doc (process-children))
(element sec (process-children))
(element sub (process-children))
(element note (process-children))
(element title (out "title"))
(element em (out "em"))

; --- the malformed ones ---------------------------------------------------
(element "" (out "empty-gi"))
(element 5 (out "not-list"))
(element ("" "para") (out "empty-gi-member"))
(element (5 "para") (out "bad-gi"))
(element ("para" 5) (out "bad-member"))
(element ("para" position:) (out "missing-value"))
(element ("para" zzz: 1) (out "unknown-qualifier"))
(element ("para" font-size: 1) (out "no-pattern-meaning"))
(element ("para" position: zzz) (out "bad-position"))
(element ("para" only: zzz) (out "bad-only"))
(element ("para" repeat: zzz) (out "bad-repeat"))
(element ("para" id: 5) (out "bad-id"))
(element ("para" class: 5) (out "bad-class"))
(element ("para" importance: "x") (out "bad-importance"))
(element ("para" priority: "x") (out "bad-priority"))
(element ("para" ("align" 5)) (out "bad-attribute-value"))
(element ("para" attributes: ("align")) (out "odd-attribute-list"))
(element ("sec" children: ("para" repeat: *)) (out "child-repeat"))

; --- and the survivor that proves parsing went on -------------------------
(element para (out "para"))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
