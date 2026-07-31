<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; lang1 - the LANGUAGE / COLLATION cluster WITH a declared default language:
; language?, current-language, with-language, string-equiv? and the
; XXPRIMITIVE `language`, together with the six collating primitives that
; depend on one (char<? char<=? char-upcase char-downcase string<? string<=?).
;
; ★A MARKED SECTION is used instead of a SYSTEM entity because a `.scm`
; included as an SGML entity cannot contain `<?` — that opens a processing
; instruction, and `char<?` is a perfectly ordinary DSSSL name.
;
; ★The measured heart of this fixture: a define-language with no `collate`
; clause has ZERO collating levels, so LangObj::compare returns 0 for EVERY
; pair. `char<?` is therefore always #f, `char<=?` always #t and
; string-equiv? always #t, no matter what the code points are. This port used
; to compare code points; the reference never does once a language is in
; play.

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

(define-language lat (toupper (#\a #\A) (#\b #\B)) (tolower (#\A #\a)))
(define-language other (toupper (#\a #\Z)))
(declare-default-language lat)

(define xlang (external-procedure "UNREGISTERED::OpenJade//Procedure::language"))

(element doc (process-children))

(element a (make sequence
  ; --- language? / current-language ------------------------------------
  (p "langp-cur"   (language? (current-language)))
  (p "langp-lat"   (language? lat))
  (p "langp-str"   (language? "en"))
  (p "langp-false" (language? #f))
  ; ★DOCUMENTED DIVERGENCE, pinned with OUR value: the XXPRIMITIVE is
  ; reachable in both, but the reference binary is built WITH
  ; SP_HAVE_LOCALE + SP_HAVE_WCHAR and hands back a RefLangObj — a live C
  ; locale that calls setlocale + wcscoll + towupper around every single
  ; comparison. This port answers #f, which is what the reference itself
  ; answers on a build without those two macros. Porting it would put
  ; process-global setlocale state under every collation; it is named in
  ; COMPLETENESS.md as an open remainder, not silently skipped. Nothing
  ; else in the language cluster depends on it — define-language is the
  ; LangObj branch, and that IS ported (everything below).
  (p "have-xlang"  (procedure? xlang))
  (p "xlang-lang?" (language? (xlang "en" "US")))

  ; --- the collating comparisons: ALL constant, because lat has no
  ; `collate` clause and therefore no levels --------------------------------
  (p "charlt-ab"   (char<? #\a #\b))
  (p "charlt-ba"   (char<? #\b #\a))
  (p "charlt-aa"   (char<? #\a #\a))
  (p "charle-ab"   (char<=? #\a #\b))
  (p "charle-ba"   (char<=? #\b #\a))
  ; char=? is NOT collating - it stays a code-point test
  (p "chareq-aa"   (char=? #\a #\a))
  (p "chareq-ab"   (char=? #\a #\b))
  (p "strlt"       (string<? "abc" "abd"))
  (p "strlt-rev"   (string<? "abd" "abc"))
  (p "strle"       (string<=? "abd" "abc"))
  ; string=? is not collating either
  (p "streq"       (string=? "abc" "abc"))
  (p "streq-no"    (string=? "abc" "abd"))
  (p "equiv-1"     (string-equiv? "abc" "zzz" 1))
  (p "equiv-9"     (string-equiv? "abc" "zzz" 9))

  ; --- the case tables ----------------------------------------------------
  (p "up-a"        (string (char-upcase #\a)))
  (p "up-b"        (string (char-upcase #\b)))
  ; a character the table does not mention folds to ITSELF - there is no
  ; ASCII fallback behind the language
  (p "up-c"        (string (char-upcase #\c)))
  (p "down-A"      (string (char-downcase #\A)))
  (p "down-B"      (string (char-downcase #\B)))

  ; --- with-language rebinds the current language for the thunk ----------
  (p "wl-value"    (with-language other (lambda () "in")))
  (p "wl-cur"      (with-language other (lambda () (language? (current-language)))))
  (p "wl-up"       (with-language other (lambda () (string (char-upcase #\a)))))
  ; ... and restores it afterwards
  (p "wl-after"    (string (char-upcase #\a)))
  (p "wl-nested"   (with-language other
                     (lambda () (with-language lat
                       (lambda () (string (char-upcase #\a)))))))))

; --- the argument gates ---------------------------------------------------
(element b (p "wl-notlang"  (with-language "en" (lambda () 1))))
(element c (p "wl-notproc"  (with-language lat "x")))
(element d (p "wl-arity"    (with-language lat (lambda (x) 1))))
(element e (p "eq-notstr"   (string-equiv? 1 "a" 1)))
(element f (p "eq-notstr2"  (string-equiv? "a" 2 1)))
(element g (p "eq-notpos"   (string-equiv? "a" "b" 0)))
(element h (p "eq-notint"   (string-equiv? "a" "b" "x")))
(element i (p "xl-notstr"   (xlang 1 "US")))
(default (empty-sosofo))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
