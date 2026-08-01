; parse1.scm - sgml-parse: the GroveManager seam. A second document becomes a
; second grove, and every table a property reads is that GROVE's, not the run's.
;
; ASCII ONLY and no angle brackets in comments (the .scm is parsed as SGML).
; Every value is minted from the reference C++ dazzle.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (yn b) (if b "yes" "no"))
(define (num n) (number->string n))

(define g1 (sgml-parse "mg1.sgml"))
(define g1b (sgml-parse "mg1.sgml"))
(define g2 (sgml-parse "mg2.sgml"))

(root
  (let* ((doc (current-node))
         (r1 (node-list-first g1))
         (r1b (node-list-first g1b))
         (r2 (node-list-first g2))
         (de1 (node-property 'document-element r1))
         (de2 (node-property 'document-element r2))
         (s1 (node-list-first (children de1))))
    (make sequence
      ; --- the loaded grove itself ------------------------------------------
      (out (string-append "len1=" (num (node-list-length g1))))
      (out (string-append "cls1=" (symbol->string (node-property 'class-name r1))))
      (out (string-append "gi1=" (gi de1)))
      (out (string-append "data1=" (data de1)))
      (out (string-append "gi2=" (gi de2)))
      ; --- groveTable_: one sysid, one grove --------------------------------
      (out (string-append "cached=" (yn (node-list=? r1 r1b))))
      (out (string-append "distinct=" (yn (node-list=? r1 r2))))
      (out (string-append "vs-doc=" (yn (node-list=? r1 doc))))
      ; --- the axes inside the loaded grove ---------------------------------
      (out (string-append "kids1=" (num (node-list-length (children de1)))))
      (out (string-append "desc1=" (num (node-list-length (descendants de1)))))
      (out (string-append "root-of-s1="
                          (yn (node-list=? (node-property 'grove-root s1) r1))))
      (out (string-append "treeroot-gi=" (gi (node-property 'tree-root s1))))
      ; --- element-with-id is PER GROVE -------------------------------------
      (out (string-append "id-in-1=" (gi (node-list-first (element-with-id "s1" r1)))))
      (out (string-append "id-in-1-from-kid="
                          (gi (node-list-first (element-with-id "s2" s1)))))
      (out (string-append "id-in-2-from-1="
                          (yn (node-list-empty? (element-with-id "i1" r1)))))
      (out (string-append "id-in-2=" (gi (node-list-first (element-with-id "i1" r2)))))
      (out (string-append "id-in-doc=" (gi (node-list-first (element-with-id "first" doc)))))
      (out (string-append "docid-in-1=" (yn (node-list-empty? (element-with-id "first" r1)))))
      ; --- the entity / notation tables are PER GROVE -----------------------
      (out (string-append "ent1=" (yn (if (entity-generated-system-id "only1" r1) #t #f))))
      (out (string-append "ent1-in-doc="
                          (yn (if (entity-generated-system-id "only1" doc) #t #f))))
      (out (string-append "not1=" (show-str (notation-system-id "n1" r1))))
      (out (string-append "not1-in-doc=" (show-str (notation-system-id "n1" doc))))
      ; --- the declaration axes ---------------------------------------------
      (out (string-append "dt1=" (node-property 'name (node-property 'governing-doctype r1))))
      (out (string-append "elems1="
                          (num (node-list-length (node-property 'elements r1)))))
      (out (string-append "elems-doc="
                          (num (node-list-length (node-property 'elements doc)))))
      ; --- address-local?: sameGrove is a real comparison now ---------------
      (out (string-append "addr-local-doc=" (yn (address-local? (node-list-address s1)))))
      (out (string-append "addr-local-self="
                          (yn (with-mode local (process-node-list s1))) )))))

(define (show-str v) (if v v "#f"))

(mode local
  (element sec (literal (yn (address-local? (node-list-address (current-node)))))))
