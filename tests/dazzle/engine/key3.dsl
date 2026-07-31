<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; key3 - the LAST FOUR names of the reference's keys[] table, which this port
; had never installed: `data`, `null`, `open` and `close`. None of them is a
; NIC of the page/column model (the COMPLETENESS note that grouped them there
; was wrong); they are:
;   data   - FormattingInstructionFlowObj's ONE characteristic, and the only
;            hasNonInheritedC in the reference that tests keyData
;            (FlowObj.cxx:2784)
;   open   - MultiLineInlineNoteFlowObj's two sosofo ports
;   close    (MultiLineInlineNote.cxx:56). That CLASS is commented out of
;            installFlowObjs, so it is deliberately not ported - but its keys
;            are installed there unconditionally all the same.
;   null   - the third keyword argument of `node-property`, next to
;            `default:` and `rcs?:` (primitive.cxx:4193).
;
; All four sit far above lastSyntacticKey, so they are INERT everywhere the
; parser tests a key: this fixture pins that they stay ordinary variable,
; procedure and let-binding names, that `data:` still reaches the formatting
; instruction and `null:` still reaches node-property, and that all four are
; still `not a valid keyword` on a class that does not name them.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

; the four names as ordinary top-level definitions
(define (open x) (+ x 1))
(define (close x) (+ x 2))

(element doc (process-children))

; `data` is a DSSSL primitive AND a key; the key does not shadow the binding
(element a (out (string-append "data=" (data (current-node)))))

; ... and all four bind as let variables and call as procedures
(element b
  (let ((data 1) (null 2))
    (out (string-append "let="
           (number->string (+ data null (open 10) (close 20)))))))

; node-property's null: / default: keyword arguments
(element c
  (out (string-append
         "np=" (node-property 'gi (current-node) default: "D" null: "N")
         "/" (node-property 'nosuch (current-node) default: "D"))))

; ... and they are unknown keywords on a class that does not name them
(element d (make paragraph open: 1 close: 2 null: 3 data: 4 (literal "D")))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
