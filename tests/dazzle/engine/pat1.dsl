<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; pat1 - the PATTERN language WITHOUT -2, the other side of pat2.dsl.
;
; ★What this pins:
;  - the whole KEYWORD half of convertToPattern is dsssl2-ONLY
;    (`KeywordObj *key = dsssl2() ? head->asKeyword() : 0`,
;    Interpreter.cxx:1466): without the flag a qualifier keyword is
;    `cannot occur in a pattern`, not `unknown pattern qualifier`;
;  - #t as a LIST MEMBER is the -2-only wildcard element, so here it is
;    `cannot be used as a generic identifier`;
;  - #t / #f as an ATTRIBUTE VALUE are -2-only too (patternAddAttribute-
;    Qualifiers, Interpreter.cxx:1683): without the flag neither converts to
;    a string and the whole qualifier list is bad;
;  - declare-id-attribute / declare-class-attribute are keys2[] entries, so
;    without -2 they are unknown top level forms;
;  - what DOES work without -2: a GI, a string or symbol, an ancestor chain
;    and the (NAME VALUE) attribute sublist.
;
; A malformed pattern is reported at PARSE time and its rule is dropped; the
; body is still consumed, so the stylesheet keeps parsing.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

; -2-only declarations
(declare-id-attribute "xid")
(declare-class-attribute "cls")

(root (process-children))
(element doc (process-children))
(element sec (process-children))
(element sub (process-children))
(element note (process-children))

; --- what works without -2 ------------------------------------------------
(element title (out "title"))
(element ("sec" "para") (out "sec-para"))
(element ("note" "para") (out "note-para"))
(element ("sub" "para") (out "sub-para"))
(element para (out "para"))
(element em (out "em"))

; --- what does not --------------------------------------------------------
(element ("para" ("align" #t)) (out "attr-has"))
(element ("para" ("align" #f)) (out "attr-missing"))
(element ("para" position: first-of-type) (out "position"))
(element ("para" id: "p1") (out "id"))
(element (#t "para") (out "wildcard"))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
