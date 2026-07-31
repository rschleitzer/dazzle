<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; pat2 - the PATTERN QUALIFIERS (Style/Pattern.cxx + the keyword half of
; Interpreter::convertToPattern), run WITH -2. pat1.dsl is the same feature
; seen from the other side: without -2 the whole keyword half is rejected.
;
; ★What this pins:
;  - the ancestor chain, the three repeat metacharacters (* ? +) and the
;    -2-only #t wildcard element;
;  - attributes:/(NAME VALUE) qualifiers, including the -2-only #t
;    (attribute-has-value) and #f (attribute-missing) values, the
;    tokenized-value rule (compare the WHOLE token string) and that an
;    IMPLIED attribute never matches;
;  - id: against the grove's own ID attribute AND against a name declared
;    with declare-id-attribute; class: against declare-class-attribute
;    (with NO declared class attribute the qualifier can match nothing);
;  - the four position: qualifiers and the two only: qualifiers, whose
;    sibling walk reads a failing firstSibling as "must be document
;    element" -> satisfied;
;  - children:, where EVERY listed element must match SOME child;
;  - importance:/priority:, which constrain nothing and only move the rule
;    in the specificity order.
;
; A MARKED SECTION, not a SYSTEM .scm entity (see key1.dsl).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(declare-id-attribute "xid")
(declare-class-attribute "cls")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (yn b) (if b "y" "n"))
(define (m pat nd) (yn (match-element? pat nd)))
(define (n-of pat nl) (number->string (node-list-length (select-elements nl pat))))

(root (process-children))

(element doc
  (let* ((secs   (select-elements (children (current-node)) "sec"))
         (s1     (node-list-first secs))
         (s2     (node-list-ref secs 1))
         (t1     (node-list-first (children s1)))
         (paras  (select-elements (children s1) "para"))
         (p1     (node-list-first paras))
         (p2     (node-list-ref paras 1))
         (sub    (node-list-first (select-elements (children s2) "sub")))
         (p3     (node-list-first (select-elements (children sub) "para")))
         (all    (descendants (current-node))))
    (make sequence
      ; --- plain forms ---------------------------------------------------
      (out (string-append "gi        " (m "para" p1) (m "sec" p1) (m 'para p1)))
      (out (string-append "any       " (m #t p1) (m #t (current-node))))
      (out (string-append "chain     " (m '("sec" "para") p1)
                                       (m '("doc" "para") p1)
                                       (m '("doc" "sec" "para") p1)))
      ; --- repeat ----------------------------------------------------------
      (out (string-append "repeat*   " (m '("doc" #t repeat: * "para") p1)
                                       (m '("doc" #t repeat: * "para") p3)))
      (out (string-append "repeat?   " (m '("sec" #t repeat: ? "para") p1)
                                       (m '("sec" #t repeat: ? "para") p3)))
      (out (string-append "repeat+   " (m '("sec" #t repeat: + "para") p1)
                                       (m '("sec" #t repeat: + "para") p3)))
      ; --- attribute qualifiers -------------------------------------------
      (out (string-append "attr      " (m '("para" ("align" "center")) p1)
                                       (m '("para" ("align" "center")) p2)
                                       (m '("para" ("kind" "one")) p2)
                                       (m '("para" ("kind" "two")) p1)))
      (out (string-append "attrkey   " (m '("para" attributes: ("align" "center")) p1)
                                       (m '("para" attributes: ("cls" "big")) p2)))
      (out (string-append "attrhas   " (m '("para" ("align" #t)) p1)
                                       (m '("para" ("align" #t)) p2)))
      (out (string-append "attrmiss  " (m '("para" ("align" #f)) p1)
                                       (m '("para" ("align" #f)) p2)))
      (out (string-append "attrtok   " (m '("para" ("toks" "a b")) p3)
                                       (m '("para" ("toks" "a")) p3)))
      (out (string-append "attrempty " (m '("para" ()) p1)))
      ; --- id / class -------------------------------------------------------
      (out (string-append "id        " (m '("para" id: "p1") p1)
                                       (m '("para" id: "p1") p2)
                                       (m '("sec" id: "s2") s2)))
      (out (string-append "class     " (m '("sec" class: "big") s1)
                                       (m '("sec" class: "big") s2)
                                       (m '("para" class: "big") p2)))
      ; --- position / only --------------------------------------------------
      (out (string-append "posftype  " (m '("para" position: first-of-type) p1)
                                       (m '("para" position: first-of-type) p2)))
      (out (string-append "posltype  " (m '("para" position: last-of-type) p1)
                                       (m '("para" position: last-of-type) p2)))
      (out (string-append "posfany   " (m '("para" position: first-of-any) p1)
                                       (m '("title" position: first-of-any) t1)))
      (out (string-append "poslany   " (m '("para" position: last-of-any) p2)
                                       (m '("title" position: last-of-any) t1)))
      (out (string-append "onlytype  " (m '("title" only: of-type) t1)
                                       (m '("para" only: of-type) p1)))
      (out (string-append "onlyany   " (m '("para" only: of-any) p3)
                                       (m '("title" only: of-any) t1)))
      ; --- children ---------------------------------------------------------
      (out (string-append "children  " (m '("sec" children: ("title")) s1)
                                       (m '("sec" children: ("title")) s2)
                                       (m '("sec" children: ("title" "para")) s1)
                                       (m '("sec" children: ("title" "note")) s1)))
      (out (string-append "childqual " (m '("sec" children: ("para" ("align" "center"))) s1)
                                       (m '("sec" children: ("para" ("align" "center"))) s2)))
      ; --- vacuous qualifiers -----------------------------------------------
      (out (string-append "vacuous   " (m '("para" priority: 3) p1)
                                       (m '("para" importance: 2) p1)))
      ; --- select-elements over the whole tree --------------------------------
      (out (string-append "select    " (n-of "para" all)
                                       (n-of '("sub" "para") all)
                                       (n-of '("para" position: first-of-type) all)
                                       (n-of '("para" ("cls" "big")) all)))
      (empty-sosofo))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
