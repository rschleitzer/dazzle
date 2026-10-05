<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; lang2 - the same cluster with NO declared language.
;
; *This is the deviation this package closes. GETCURLANG (primitive.cxx:4639)
; takes the context language, else the DECLARED DEFAULT - and that default is
; #f until declare-default-language sets one. So without a language every
; COLLATING primitive reports `no current language` and yields the error
; object: char<? char<=? char-upcase char-downcase string<? string<=? and
; string-equiv?. This port used to answer them anyway, comparing code points
; and folding ASCII; that fallback is gone.
;
; *The two primitives that are NOT collating still work: char=? and string=?
; are plain code-point tests in the reference too. And current-language
; answers #f rather than erroring - it is the one language primitive with no
; gate.
;
; The diagnostic carries NO file/line: the reference's GETCURLANG macro calls
; message() without setNextLocation, so the location is whatever was set
; last. Same for with-language's tooManyArgs.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (show v)
  (cond ((string? v) (string-append "s:" v))
        ((boolean? v) (if v "#t" "#f"))
        (else "?")))
(define (p tag v) (out (string-append tag "=" (show v))))
(define-language lat (toupper (#\a #\A)))

(element doc (process-children))

; the two that answer without a language
(element a (make sequence
  (p "curlang"    (current-language))
  (p "langp-cur"  (language? (current-language)))
  (p "chareq"     (char=? #\a #\a))
  (p "streq"      (string=? "ab" "ab"))))

; every collating primitive, one per element so its diagnostic is attributable
(element b (p "charlt"  (char<? #\a #\b)))
(element c (p "charle"  (char<=? #\a #\b)))
(element d (p "up"      (string (char-upcase #\a))))
(element e (p "down"    (string (char-downcase #\A))))
(element f (p "strlt"   (string<? "abc" "abd")))
(element g (p "strle"   (string<=? "abc" "abd")))
(element h (p "equiv"   (string-equiv? "a" "b" 1)))
; ... but inside with-language they all work again
(element i (p "wl-up"   (with-language lat (lambda () (string (char-upcase #\a))))))
(default (empty-sosofo))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
