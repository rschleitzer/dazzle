; chars1.scm - per-character grove nodes (data-char).
;
; The reference stores character data as a DataChunk and hands out DataNodes,
; which are (chunk, index) VIEWS: ONE grove node per character
; (spgrove/GroveBuilder.cxx:586-635). Observable through children/descendants/
; follow, the class name, the `char` property, `data` and node identity.
; doc.sgml's first p holds `First `, an em element and ` text.` = 6 + 1 + 6 nodes.
; (An SGML start-tag in a comment would be parsed as markup, hence no angle
; brackets anywhere in this file.)
;
; ASCII ONLY (the .scm is read as an 8-bit charset).
;
; NOT covered on purpose: `preced` OF a char node - the reference ABORTS there
; (CANNOT_HAPPEN in SiblingNodeListObj::nodeListChunkRest,
; style/primitive.cxx:5695, because nextChunkSibling fails mid-chunk). We answer
; the consistent count instead.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (cls n1)
  (if (node-list-empty? n1) "EMPTY"
      (symbol->string (node-property 'class-name n1 default: 'none))))
(define (strf v) (if (string? v) v (if (char? v) (string v) "#f")))
(define (num n) (number->string n))

(element doc
  (let* ((p1 (node-list-ref (select-elements (children (current-node)) "p") 0))
         (kids (children p1))
         (c0 (node-list-ref kids 0))
         (c1 (node-list-ref kids 1))
         (c3 (node-list-ref kids 3))
         (em (node-list-ref kids 6)))
    (make sequence
      ; one node per character, the element in between
      (out (string-append "children=" (num (node-list-length kids))))
      (out (string-append "descendants=" (num (node-list-length (descendants p1)))))
      (out (string-append "class0=" (cls c0)))
      (out (string-append "class6=" (cls em)))
      ; a char node is a leaf with no gi
      (out (string-append "char-gi=" (strf (gi c3))))
      (out (string-append "char-children=" (num (node-list-length (children c3)))))
      (out (string-append "char-parent=" (cls (parent c3))))
      ; `char` property and the one-character `data` of a member, against the
      ; chunk-wise `data` of the whole list
      (out (string-append "char-prop=[" (strf (node-property 'char c0 default: #f)) "]"))
      (out (string-append "data-c0=[" (strf (data c0)) "]"))
      (out (string-append "data-c1=[" (strf (data c1)) "]"))
      (out (string-append "data-list=[" (strf (data kids)) "]"))
      ; the sibling axis counts characters
      (out (string-append "follow-char3=" (num (node-list-length (follow c3)))))
      (out (string-append "follow-em=" (num (node-list-length (follow em)))))
      (out (string-append "preced-em=" (num (node-list-length (preced em)))))
      ; identity is (chunk, index), not the object: a second children call
      ; yields equal views
      (out (string-append "same-pos=" (if (node-list=? c0 (node-list-ref (children p1) 0)) "YES" "NO")))
      (out (string-append "other-pos=" (if (node-list=? c0 c1) "YES" "NO")))
      ; element selection is unaffected by the expansion
      (out (string-append "select-em=" (num (node-list-length (select-elements kids "em")))))
      ; processing a node-list of char nodes stays CHUNK-WISE: each run once
      (out "processed=[")
      (process-node-list kids)
      (out "]"))))
(default (empty-sosofo))
