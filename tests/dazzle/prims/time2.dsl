<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; time2 - the DIAGNOSTICS and the SIGNATURES of the time family. One probe
; per element, because an error result unwinds its whole construction rule.
;
; *The two gates are different messages on the same family: time->string
; wants an EXACT INTEGER, the four comparisons want STRINGS first and only
; then a parsable one (notATimeString - the only place in the engine that
; message is reachable from). The ordinal in the message is the argument
; index, so the second-argument arms pin that the check runs per argument.
;
; *The last two probes pin the installed SIGNATURES rather than the
; primitives: time is (0,0,0) and time->string is (1,1,0), so a third
; argument to the one and a first to the other is `too many arguments for
; function` - reported by the CALL, after which the primitive still runs on
; the arguments it was given and yields its ordinary value. Both values are
; therefore printed alongside the diagnostic.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (show v)
  (cond ((string? v) (string-append "s:" v))
        ((number? v) (string-append "n:" (number->string v)))
        ((boolean? v) (if v "#t" "#f"))
        (else "?")))
(define (p tag v) (out (string-append tag "=" (show v))))

(element doc (process-children))

(element a (p "ts-notint"   (time->string "x")))
(element b (p "lt-notstr"   (time<? 1 "2000")))
(element c (p "lt-notstr2"  (time<? "2000" 2)))
(element d (p "lt-nottime"  (time<? "hello" "2000")))
(element e (p "lt-nottime2" (time<? "2000" "hello")))
(element f (p "ts-arity"    (time->string 0 #t 9)))
(element g (p "t-arity"     (exact? (time 1))))
(default (empty-sosofo))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
