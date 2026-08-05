; num5.scm - the NUMBERING CACHE's state machine (NumberCache.cxx). num4 pins
; what the numbering primitives ANSWER; this one pins that they answer the same
; when the cache is carrying state from an earlier query.
;
; The cache keeps ONE position per GI and continues the document-order walk
; from there, so the order in which the queries are asked is the whole point:
; the same node twice (the early return), a node BEFORE the cached one (the
; walk has to restart at the document element), two GIs interleaved (separate
; entries), and element-number-list mixed in - it keys its entry by the RESET
; gi and stores a sub-position that the plain form clears, so the two forms
; share the table and can cross-talk.
;
; Every value here must be independent of the query order. The golden is
; minted from the reference, which has the same cache and the same seam.
;
; ASCII ONLY, and MARKUP-FREE (see num1.scm).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (show v)
  (cond ((number? v) (number->string v))
        ((string? v) (string-append "s:" v))
        ((boolean? v) (if v "#t" "#f"))
        ((null? v) "()")
        ((pair? v) (string-append "(" (show (car v)) " " (show (cdr v)) ")"))
        (else "?")))
(define (p tag v) (out (string-append tag "=" (show v))))

(define (ps) (select-elements (descendants (current-node)) "p"))
(define (secs) (select-elements (descendants (current-node)) "sec"))
(define (nth nd i) (node-list-ref nd i))

(element doc (make sequence

  ; --- forward: every query continues the cached walk --------------------
  (p "f0"     (element-number (nth (ps) 0)))
  (p "f1"     (element-number (nth (ps) 1)))
  (p "f2"     (element-number (nth (ps) 2)))
  ; the SAME node again - answered from the entry without walking
  (p "f2again" (element-number (nth (ps) 2)))
  ; BACKWARDS - the cached position is past the target, so the walk must
  ; start over at the document element instead of running off the end
  (p "b0"     (element-number (nth (ps) 0)))
  (p "b1"     (element-number (nth (ps) 1)))
  ; forward again, past everything seen so far
  (p "f7"     (element-number (nth (ps) 7)))

  ; --- a second GI keeps its own entry, interleaved with the first -------
  (p "s0"     (element-number (nth (secs) 0)))
  (p "f3"     (element-number (nth (ps) 3)))
  (p "s2"     (element-number (nth (secs) 2)))
  (p "f4"     (element-number (nth (ps) 4)))
  (p "s1"     (element-number (nth (secs) 1)))

  ; --- the reset form shares the table with the plain one ----------------
  (p "l4"     (element-number-list (list "chap" "sec" "p") (nth (ps) 4)))
  ; backwards again, now through the reset form
  (p "l1"     (element-number-list (list "chap" "sec" "p") (nth (ps) 1)))
  (p "l1again" (element-number-list (list "chap" "sec" "p") (nth (ps) 1)))
  ; the reset element ITSELF: nothing of its own gi follows it
  (p "lsec1"  (element-number-list (list "chap" "sec") (nth (secs) 1)))
  (p "lsec2"  (element-number-list (list "chap" "sec") (nth (secs) 2)))

  ; --- and the plain form once more, after the reset form wrote its
  ; sub-position into the same entries
  (p "f5"     (element-number (nth (ps) 5)))
  (p "s1b"    (element-number (nth (secs) 1)))
  (p "f0b"    (element-number (nth (ps) 0)))
))
(default (empty-sosofo))
