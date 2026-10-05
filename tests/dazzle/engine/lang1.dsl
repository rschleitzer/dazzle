<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; lang1 - define-language and its COLLATION half (style/LangObj.cxx): the
; positive matrix. Everything here is reachable only through a stylesheet
; that declares a language, so the reference binary is the only oracle.
;
; What the golden pins:
;  - a language with NO collate clause has ZERO levels, so LangObj::compare
;    answers 0 for EVERY pair: string<? is #f and string<=? #t whatever the
;    code points say (that is the reference, not a shortcut);
;  - a collating ORDER puts the characters in the declared sequence, which
;    has nothing to do with their code points (z before a if declared so);
;  - a multi-collating ELEMENT ("ch") is ONE unit sorting between c and d,
;    because asCollatingElts takes the LONGEST prefix with a position;
;  - a collating SYMBOL takes a position of its own, and one that is never
;    given a position keeps charMax and therefore sorts LAST;
;  - explicit WEIGHTS per level make a second-level distinction: a and A are
;    equivalent at strength 1 and different at strength 2, which is what
;    string-equiv? reads and what a two-level string<? falls back on;
;  - a STRING weight contributes one weight per CHARACTER;
;  - an UNKNOWN character takes the default position, which without a #t item
;    has no weights at all - atLevel then stops at the first miss and returns
;    a SHORTER level string, so a string containing an unknown character
;    sorts FIRST ("z" < "a"). A #t item in the order list gives that default
;    position a place, and unknown characters collate there instead;
;  - a BACKWARD level compares the collating elements right to left (the
;    French accent rule) and a POSITION level interleaves the index;
;  - the case tables are a CharMap, so a repeated left-hand character is
;    REPLACED: the last pair wins, and a character with no pair is identity;
;  - with-language switches the language for the extent of a thunk,
;    current-language reports it, and declare-default-language is the
;    fallback when no with-language is active.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (b v) (if v "#t" "#f"))
(define (p tag v) (out (string-append tag "=" v)))
(define (pb tag v) (p tag (b v)))

; --- a language with no collate clause at all: zero levels ----------------
(define-language nocoll
  (toupper (#\a #\A) (#\b #\B))
  (tolower (#\A #\a)))

; --- one forward level, an order that is NOT the code-point order ---------
(define-language plain
  (collate
    (order ((forward))
       #\z #\y #\a #\b)))

; --- multi-collating element, collating symbol, two levels, weights -------
(define-language full
  (collate
    (element ch "ch")
    (symbol lowest)
    (symbol nopos)
    (order ((forward) (forward))
       lowest
       #\a
       (#\A (#\a) (#\A))
       #\b
       #\c
       ch
       #\d
       (#\e ("ab") (#\e))
       (#\q (nopos) (#\q))))
  (toupper (#\a #\A) (#\a #\Z) (#\c #\C))
  (tolower (#\A #\a)))

; --- the default position placed explicitly with #t -----------------------
(define-language deflt
  (collate
    (order ((forward))
       #\a #\b #t #\c #\d)))

; --- a backward first level, and a position level -------------------------
(define-language backw
  (collate
    (order ((backward))
       #\a #\b #\c)))

(define-language posl
  (collate
    (order ((forward) (position))
       #\a #\b)))

(declare-default-language plain)

(define (with l thunk) (with-language l thunk))

(root
 (make sequence
  ; the default language, declared above: z sorts before a
  (pb "plain z<a" (string<? "z" "a"))
  (pb "plain a<z" (string<? "a" "z"))
  (pb "plain y<a" (string<? "y" "a"))
  (pb "plain char z<a" (char<? #\z #\a))
  (pb "plain char a<=a" (char<=? #\a #\a))
  (pb "plain zz<za" (string<? "zz" "za"))
  ; an unknown character truncates the level string and sorts first
  (pb "plain Q<a" (string<? "Q" "a"))
  (pb "plain a<Q" (string<? "a" "Q"))
  (pb "plain equiv Q x 1" (string-equiv? "Q" "x" 1))

  ; zero levels: every pair compares equal
  (pb "nocoll a<b" (with nocoll (lambda () (string<? "a" "b"))))
  (pb "nocoll b<a" (with nocoll (lambda () (string<? "b" "a"))))
  (pb "nocoll a<=b" (with nocoll (lambda () (string<=? "a" "b"))))
  (pb "nocoll equiv a b 1" (with nocoll (lambda () (string-equiv? "a" "b" 1))))
  (pb "nocoll char a<b" (with nocoll (lambda () (char<? #\a #\b))))
  ; ... but the case tables still work, and the LAST pair wins
  (p "nocoll up-a" (with nocoll (lambda () (string (char-upcase #\a)))))
  (p "nocoll up-b" (with nocoll (lambda () (string (char-upcase #\b)))))
  (p "nocoll up-z" (with nocoll (lambda () (string (char-upcase #\z)))))
  (p "nocoll down-A" (with nocoll (lambda () (string (char-downcase #\A)))))
  (p "nocoll down-B" (with nocoll (lambda () (string (char-downcase #\B)))))

  ; the full language
  (pb "full c<ch" (with full (lambda () (string<? "c" "ch"))))
  (pb "full ch<d" (with full (lambda () (string<? "ch" "d"))))
  (pb "full cz<ch" (with full (lambda () (string<? "cz" "ch"))))
  (pb "full ch<c" (with full (lambda () (string<? "ch" "c"))))
  (pb "full a<A" (with full (lambda () (string<? "a" "A"))))
  (pb "full A<b" (with full (lambda () (string<? "A" "b"))))
  (pb "full a<=A" (with full (lambda () (string<=? "a" "A"))))
  (pb "full equiv a A 1" (with full (lambda () (string-equiv? "a" "A" 1))))
  (pb "full equiv a A 2" (with full (lambda () (string-equiv? "a" "A" 2))))
  (pb "full equiv a A 9" (with full (lambda () (string-equiv? "a" "A" 9))))
  (pb "full equiv a a 1" (with full (lambda () (string-equiv? "a" "a" 1))))
  ; e carries the two-character string weight "ab" at level 0
  (pb "full e<b" (with full (lambda () (string<? "e" "b"))))
  (pb "full a<e" (with full (lambda () (string<? "a" "e"))))
  (pb "full equiv e ab 1" (with full (lambda () (string-equiv? "e" "ab" 1))))
  ; q's level-0 weight is a collating symbol that never got a position
  (pb "full q<d" (with full (lambda () (string<? "q" "d"))))
  (pb "full d<q" (with full (lambda () (string<? "d" "q"))))
  ; the case tables of the full language: last pair wins, miss is identity
  (p "full up-a" (with full (lambda () (string (char-upcase #\a)))))
  (p "full up-c" (with full (lambda () (string (char-upcase #\c)))))
  (p "full up-x" (with full (lambda () (string (char-upcase #\x)))))
  (p "full down-A" (with full (lambda () (string (char-downcase #\A)))))
  (p "full down-C" (with full (lambda () (string (char-downcase #\C)))))

  ; the explicit default position
  (pb "deflt b<z" (with deflt (lambda () (string<? "b" "z"))))
  (pb "deflt z<c" (with deflt (lambda () (string<? "z" "c"))))
  (pb "deflt z<z" (with deflt (lambda () (string<? "z" "z"))))
  (pb "deflt equiv z y 1" (with deflt (lambda () (string-equiv? "z" "y" 1))))
  (pb "deflt a<z" (with deflt (lambda () (string<? "a" "z"))))

  ; backward and position levels
  (pb "backw ab<ba" (with backw (lambda () (string<? "ab" "ba"))))
  (pb "backw ba<ab" (with backw (lambda () (string<? "ba" "ab"))))
  (pb "backw ac<bc" (with backw (lambda () (string<? "ac" "bc"))))
  (pb "posl ab<ba" (with posl (lambda () (string<? "ab" "ba"))))
  (pb "posl aa<ab" (with posl (lambda () (string<? "aa" "ab"))))

  ; the language values themselves
  (pb "language? full" (language? full))
  (pb "language? nocoll" (language? nocoll))
  (pb "language? \"x\"" (language? "x"))
  (pb "current is plain" (equal? (current-language) plain))
  (pb "current in with" (with full (lambda () (equal? (current-language) full))))
  (pb "current after with" (equal? (current-language) plain))
 ))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
