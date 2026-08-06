; num7.scm - the CHILD-NUMBER cache and the sibling HINT, as state machines.
; num4 pins what child-number / last-sibling? / absolute-last-sibling? ANSWER;
; this one pins that they answer the same when the machinery is carrying state
; from an earlier query. It is num5's counterpart for the second cache.
;
; Two pieces of state are exercised, and they have different shapes:
;
;   NumberCache::childNumber keeps ONE entry per (tree LEVEL, gi) and resumes
;   the sibling count from the node it last answered for. So the order matters
;   in four ways: the same node twice (the early return), a node BEFORE the
;   cached one (no resume - the count restarts at the first sibling), two GIs
;   in the SAME group (separate entries), and the same gi at two different
;   LEVELS (separate tables, which is why the cache is a vector of them).
;
;   GroveNode.group_index keeps one (parent, slot) hint for the whole grove, so
;   last-sibling? and absolute-last-sibling? start where the previous question
;   stopped - including when that was in a different group entirely.
;
; Every value here must be independent of the query order. The golden is minted
; from the reference, which has the same cache and the same seam.
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

(define (chaps)  (select-elements (descendants (current-node)) "chap"))
(define (secs)   (select-elements (descendants (current-node)) "sec"))
(define (ps)     (select-elements (descendants (current-node)) "p"))
(define (titles) (select-elements (descendants (current-node)) "title"))
(define (nth nd i) (node-list-ref nd i))

(element doc (make sequence

  ; --- one level, one gi: forward, repeat, backwards ---------------------
  (p "c0"      (child-number (nth (chaps) 0)))
  (p "c1"      (child-number (nth (chaps) 1)))
  (p "c2"      (child-number (nth (chaps) 2)))
  ; the SAME node again - answered from the entry without counting
  (p "c2again" (child-number (nth (chaps) 2)))
  ; BACKWARDS - the cached node is past this one, so the count has to start
  ; over at the first sibling instead of continuing
  (p "c0b"     (child-number (nth (chaps) 0)))

  ; --- two GIs in the same group keep separate entries -------------------
  ; title 0 and p 0/1 are siblings inside chapter one
  (p "t0"      (child-number (nth (titles) 0)))
  (p "pp0"     (child-number (nth (ps) 0)))
  (p "t1"      (child-number (nth (titles) 1)))
  (p "pp1"     (child-number (nth (ps) 1)))

  ; --- the same gi at TWO LEVELS, interleaved ----------------------------
  ; ps 0/1 are chapter children (level 1), ps 2..5 are section children
  ; (level 2): a per-level table is the only thing that keeps these apart,
  ; and a single shared entry would resume the wrong count here
  (p "l2a"     (child-number (nth (ps) 2)))
  (p "l1a"     (child-number (nth (ps) 1)))
  (p "l2b"     (child-number (nth (ps) 3)))
  (p "l1b"     (child-number (nth (ps) 0)))
  (p "l2c"     (child-number (nth (ps) 4)))
  ; and the sections themselves, one level up again
  (p "s0"      (child-number (nth (secs) 0)))
  (p "s2"      (child-number (nth (secs) 2)))
  (p "s1"      (child-number (nth (secs) 1)))

  ; --- the sibling hint: same group, other group, backwards --------------
  (p "ls-p0"   (last-sibling? (nth (ps) 0)))
  (p "ls-p1"   (last-sibling? (nth (ps) 1)))
  (p "als-p0"  (absolute-last-sibling? (nth (ps) 0)))
  (p "als-p1"  (absolute-last-sibling? (nth (ps) 1)))
  ; a question in a DIFFERENT group between two in this one
  (p "ls-s0"   (last-sibling? (nth (secs) 0)))
  (p "ls-p0b"  (last-sibling? (nth (ps) 0)))
  (p "als-c0"  (absolute-last-sibling? (nth (chaps) 0)))
  (p "als-c2"  (absolute-last-sibling? (nth (chaps) 2)))
  ; the first sibling of its group, asked after the hint sits at the end
  (p "ls-t0"   (last-sibling? (nth (titles) 0)))
  (p "fs-t0"   (first-sibling? (nth (titles) 0)))
  (p "afs-t0"  (absolute-first-sibling? (nth (titles) 0)))
  ; the last paragraph of the last section, both predicates
  (p "ls-p5"   (last-sibling? (nth (ps) 5)))
  (p "als-p5"  (absolute-last-sibling? (nth (ps) 5)))
))
(default (empty-sosofo))
