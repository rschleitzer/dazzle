<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; time1 - the TIME family (primitive.h:58-59 and 216-219): time,
; time->string and the four comparisons over timeConv. Value cases only;
; everything that reports a message lives in time2.
;
; *A MARKED SECTION is used instead of a SYSTEM entity, for the same reason
; lang1 uses one: a `.scm` read as an SGML entity cannot contain `<?`, and
; `time<?` is a perfectly ordinary DSSSL name.
;
; *The harness runs this with TZ=EST5 - a POSIX zone string with a FIXED
; offset and no DST rule, so it needs no tzdata and localtime stays both
; deterministic and distinguishable from gmtime.
;
; *The heart of this fixture is timeConv (primitive.cxx:5191), whose parse is
; two sscanf attempts and whose quirks are contract here, not accidents:
;   - a bare year is NOT January first. The switch falls from `case 1`
;     through `case 2` into the month decrement, so "1999" is month -1 day 1,
;     which mktime normalizes to 1998-12-01. Pinned three ways below.
;   - an unparsable string is an error, but an EMPTY one is not: sscanf
;     answers 0 for "hello" (-> notATimeString, in time2) and EOF for "",
;     which lands in the `default` arm and yields month -1 day 0 = 1999-11-30.
;   - only a year of 1900 or more is treated as a full year, so "1000-01-01"
;     is the year 2900 and sorts AFTER "2000".
;   - a year below 38 gets the Y2K century added, one above does not: "37" is
;     2037 and "38" is 1938.

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

(element a (make sequence
  ; --- (time) --------------------------------------------------------------
  ; the value is the wall clock, so only its shape is pinnable: an EXACT
  ; integer (makeInteger of a long), and past every plausible build date.
  (p "t-exact"   (exact? (time)))
  (p "t-past"    (> (time) 1700000000))

  ; --- time->string --------------------------------------------------------
  ; sprintf("%04d-%02d-%02dT%02d:%02d:%02d") over gmtime or localtime. The
  ; second argument selects gmtime only when it is not #f, so an explicit #f
  ; means LOCAL, exactly like passing nothing.
  (p "gm-0"      (time->string 0 #t))
  (p "loc-0"     (time->string 0))
  (p "loc-0f"    (time->string 0 #f))
  (p "gm-1e9"    (time->string 1000000000 #t))
  (p "loc-1e9"   (time->string 1000000000))
  (p "gm-neg"    (time->string -1 #t))

  ; --- the four comparisons, on full dates ---------------------------------
  (p "lt"        (time<? "2000-01-01" "2001-01-01"))
  (p "lt-rev"    (time<? "2001-01-01" "2000-01-01"))
  (p "gt"        (time>? "2001-01-01" "2000-01-01"))
  (p "gt-rev"    (time>? "2000-01-01" "2001-01-01"))
  (p "le-eq"     (time<=? "2000-01-01" "2000-01-01"))
  (p "ge-eq"     (time>=? "2000-01-01" "2000-01-01"))
  (p "le-lt"     (time<=? "2000-01-01" "2001-01-01"))
  (p "ge-gt"     (time>=? "2000-01-01" "2001-01-01"))

  ; --- the time-of-day form: the FIRST sscanf, whose defaults are today ----
  (p "tod"       (time<? "01:00:00" "02:00:00"))
  (p "tod-2"     (time<? "12:00" "13:00"))
  (p "tod-eq"    (time<=? "12:00:00" "12:00:00"))

  ; --- the date form and its quirks ----------------------------------------
  ; a bare year is the DECEMBER FIRST of the year before
  (p "yr-lt-jan" (time<? "1999" "1999-01-01"))
  (p "yr-eq-dec" (time<=? "1999" "1998-12-01"))
  (p "yr-gt-dec" (time<? "1999" "1998-12-01"))
  ; year+month IS the first of that month (case 2 sets mday, the decrement
  ; turns the 1-based month into tm_mon)
  (p "ym-le"     (time<=? "2000-03" "2000-03-01"))
  (p "ym-lt"     (time<? "2000-03" "2000-03-01"))
  ; the Y2K window
  (p "y2k-38-37" (time<? "38" "37"))
  (p "y2k-37-38" (time<? "37" "38"))
  ; a 4-digit year below 1900 is NOT reduced: 1000 means 2900
  (p "yr-1000"   (time<? "1000-01-01" "2000"))
  (p "yr-3000"   (time<? "2000" "3000-01-01"))
  ; any non-digit run separates date from time
  (p "sep-space" (time<? "2000-01-01 12:00:00" "2000-01-01T13:00:00"))
  (p "sep-tail"  (time<? "2000-01-01xyz" "2001"))
  ; a leading minus parses as a negative year, so "-5" is 1994-12-01
  (p "neg-year"  (time<? "-5" "2000"))
  ; an EMPTY string is not an error - sscanf answers EOF, not 0
  (p "empty-lt"  (time<? "" "2000"))
  (p "empty-eq"  (time>=? "" "1999-11-30"))
  (p "blank"     (time<? " " "2000"))
))
(default (empty-sosofo))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
