<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; query4 / query4b - the shape of a BODY, run twice on the same file because
; half of it is -2-gated (query4 without the flag, query4b with it). Found
; while pinning the query forms next door: parseBegin is where a query form's
; lambda body comes from.
;
;  - parseBegin (SchemeParser.cxx:1247) parses its FIRST expression WITHOUT
;    allowCloseParen in both modes, so an EMPTY body is `unexpected token
;    ")"` and the form is dropped - in both modes;
;  - the SEQUENCE half is -2-ONLY: without the flag a body is exactly ONE
;    expression, and a second one is `missing closing parenthesis` reported
;    TWICE - tokenRecover ungets the offending token and answers SUCCESS, so
;    the enclosing body-close trips over the same token again. Under -2 the
;    same bodies are ordinary sequences and the last value wins.
;
; Deliberately no string literals in the malformed forms: an unexpected `"`
; leaves the lexer inside a string and the cascade swallows the rest of the
; file, which would hide the later cases.
;
; Pure ASCII, marked section - see query1.dsl.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (num n) (number->string n))

; --- an EMPTY body, procedure and lambda ---------------------------------
(define (empty1 x))
(define empty2 (lambda (z)))

; --- TWO-expression bodies: define, let, lambda --------------------------
(define (two x) 1 2)
(define (three x) (let ((y 3)) y 4))
(define (four x) ((lambda (z) z 5) 6))

(root (process-children))
(element doc
  (make sequence
    (out (string-append "two=" (num (two 0))))
    (out (string-append "three=" (num (three 0))))
    (out (string-append "four=" (num (four 0))))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
