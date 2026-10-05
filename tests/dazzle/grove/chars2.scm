; chars2.scm - node-list navigation ACROSS data-chunk boundaries.
;
; chars1 pins the per-character node contract; this pins what the node-list
; must do with it once a walk lands INSIDE a data run: node-list-rest stepping
; character by character through a chunk, node-list-ref addressing a position
; that has no member of its own, `data` over a partially consumed first member,
; and select-elements skipping a chunk it starts in the middle of.
;
; These are exactly the cases the lazy node-list representation resolves
; through its prefix index (ELObj.NodeListObj) instead of a flat per-character
; array, so they are the ones that must stay reference-identical.
;
; doc.sgml's first p is `First ` + em + ` text.` = 6 + 1 + 6 = 13 members.
; (An SGML start-tag in a comment would be parsed as markup, hence no angle
; brackets anywhere in this file.)
;
; ASCII ONLY (the .scm is read as an 8-bit charset).
;
; NOT covered on purpose: `preced` OF a char node - the reference ABORTS there
; (CANNOT_HAPPEN in SiblingNodeListObj::nodeListChunkRest,
; style/primitive.cxx:5695).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (strf v) (if (string? v) v (if (char? v) (string v) "#f")))
(define (num n) (number->string n))
(define (rest-n n1 k) (if (= k 0) n1 (rest-n (node-list-rest n1) (- k 1))))
; node-property wants a SINGLETON, and half the probes below hand it a longer
; list on purpose - take the first node explicitly.
(define (cls n1)
  (if (node-list-empty? n1) "EMPTY"
      (symbol->string (node-property 'class-name (node-list-first n1) default: 'none))))

(element doc
  (let* ((p1 (node-list-ref (select-elements (children (current-node)) "p") 0))
         (kids (children p1))
         (desc (descendants p1)))
    (make sequence
      ; --- node-list-rest walking INTO a chunk ---------------------------
      (out (string-append "len0=" (num (node-list-length kids))))
      (out (string-append "len3=" (num (node-list-length (rest-n kids 3)))))
      (out (string-append "len6=" (num (node-list-length (rest-n kids 6)))))
      (out (string-append "len13=" (num (node-list-length (rest-n kids 13)))))
      (out (string-append "first3=[" (strf (data (node-list-first (rest-n kids 3)))) "]"))
      (out (string-append "first6=" (cls (rest-n kids 6))))
      (out (string-append "first7=[" (strf (data (node-list-first (rest-n kids 7)))) "]"))
      ; --- `data` over a partially consumed first member -----------------
      (out (string-append "data0=[" (strf (data kids)) "]"))
      (out (string-append "data3=[" (strf (data (rest-n kids 3))) "]"))
      (out (string-append "data6=[" (strf (data (rest-n kids 6))) "]"))
      (out (string-append "data7=[" (strf (data (rest-n kids 7))) "]"))
      (out (string-append "data12=[" (strf (data (rest-n kids 12))) "]"))
      ; --- node-list-ref at positions with no member of their own --------
      (out (string-append "ref5=[" (strf (data (node-list-ref kids 5))) "]"))
      (out (string-append "ref6=" (cls (node-list-ref kids 6))))
      (out (string-append "ref8=[" (strf (data (node-list-ref kids 8))) "]"))
      (out (string-append "ref12=[" (strf (data (node-list-ref kids 12))) "]"))
      (out (string-append "ref13=" (cls (node-list-ref kids 13))))
      ; a rest-ed first and the same position ref'd are the SAME node
      (out (string-append "same3=" (if (node-list=? (node-list-first (rest-n kids 3))
                                                    (node-list-ref kids 3)) "YES" "NO")))
      (out (string-append "same8=" (if (node-list=? (node-list-first (rest-n kids 8))
                                                    (node-list-ref kids 8)) "YES" "NO")))
      ; --- select-elements starting inside a chunk -----------------------
      (out (string-append "sel0=" (num (node-list-length (select-elements kids "em")))))
      (out (string-append "sel3=" (num (node-list-length (select-elements (rest-n kids 3) "em")))))
      (out (string-append "sel7=" (num (node-list-length (select-elements (rest-n kids 7) "em")))))
      ; --- the sibling axis from a mid-chunk position --------------------
      (out (string-append "follow5=" (num (node-list-length (follow (node-list-ref kids 5))))))
      (out (string-append "follow8=" (num (node-list-length (follow (node-list-ref kids 8))))))
      ; --- descendants keeps document order across the boundaries --------
      (out (string-append "desc=" (num (node-list-length desc))))
      (out (string-append "desc6=" (cls (node-list-ref desc 6))))
      (out (string-append "desc7=[" (strf (data (node-list-ref desc 7))) "]"))
      (out (string-append "desc-data=[" (strf (data desc)) "]"))
      (out (string-append "desc-rest=[" (strf (data (rest-n desc 7))) "]")))))
(default (empty-sosofo))
