<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; pat4 - SPECIFICITY, the second half of what a qualifier is for: which of
; several matching construction rules wins. Pattern::compareSpecificity walks
; nine dimensions IN ORDER - importance, id, class, gi, repeat, priority,
; only, position, attribute - and the first difference decides.
;
; *What this pins:
;  - id: outranks an attribute qualifier, class: outranks a plain GI, and
;    priority: (dimension 5) outranks BOTH only: and position: (6 and 7),
;    which in turn outrank the attribute dimension (8);
;  - importance: comes FIRST, so it overrides every other difference;
;  - a repeat qualifier SUBTRACTS one from the repeat dimension, so a
;    pattern with a variable repeat loses against an otherwise equal one;
;  - and the tie: two patterns of identical specificity matching one node
;    are `node matches more than one pattern with the same specificity`.
;
; A MARKED SECTION, not a SYSTEM .scm entity (see key1.dsl).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(declare-id-attribute "xid")
(declare-class-attribute "cls")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

(root (process-children))
(element doc (process-children))
(element sub (process-children))
(element note (process-children))

; --- para: id: > class: > attribute, and priority: > position: -----------
(element ("para" id: "p1") (out "para-id"))
(element ("para" ("align" "center")) (out "para-attr-align"))
(element ("para" class: "big") (out "para-class"))
(element ("para" ("kind" "one")) (out "para-attr-kind"))
(element ("para" position: last-of-type) (make sequence (out "para-pos-last") (process-children)))
(element ("para" ("toks" "a b")) (out "para-attr-toks"))
(element para (out "para-plain"))

; --- title: priority: beats position:, importance: beats everything ------
(element ("title" priority: 5) (out "title-priority"))
(element ("title" position: first-of-any) (out "title-pos"))
(element title (out "title-plain"))

; --- em: importance: first -----------------------------------------------
(element ("em" importance: 2) (out "em-importance"))
(element ("em" priority: 9) (out "em-priority"))
(element em (out "em-plain"))

; --- sec: a deliberate TIE between two attribute qualifiers --------------
; *both rules print the SAME text on purpose: which one of an equal-
; specificity run fires is not a contract - the reference sorts its rules
; with qsort, which is not stable. The DIAGNOSTIC is the contract.
(element ("sec" ("cls" "big")) (make sequence (out "sec-tie") (process-children)))
(element ("sec" ("xid" "s1")) (make sequence (out "sec-tie") (process-children)))
(element sec (process-children))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
