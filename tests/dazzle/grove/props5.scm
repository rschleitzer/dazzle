; props5.scm - the ENTITY-REFERENCE branch of the grove: the sdata,
; external-data, subdocument and non-sgml node classes, and the pi class's
; second origin (PiEntityNode, a pi node that HAS an entity).
;
; ASCII ONLY, and no angle brackets AND NO AMPERSANDS in comments (the .scm is
; included as an SGML entity, so an entity reference in a comment is parsed).
;
; Every value is minted from the reference C++ dazzle. null: / default: are
; both supplied so the golden DISCRIMINATES the four outcomes:
;   a value    - accessOK
;   NULLACC    - accessNull
;   NOTINCL    - accessNotInClass (or an unknown property name)
;   EMPTYNL    - the step BEFORE this one already answered an empty node-list
;
; The fixture document gives each class its own paragraph, so the probe node is
; always the SECOND child of the paragraph:
;   p1  A excl B      sdata, name known to the built-in sdata table
;   p2  A U-0041 B    sdata resolved by convertUnicodeCharName
;   p3  D logo E      external-data (an NDATA entity reference)
;   p4  F pi-ent G    pi WITH an entity (PiEntityNode)
;   p5  H subd I      subdocument (never sub-parsed - the grove app gets one event)
;   p6  J 127 K       non-sgml (the document's own SGML declaration leaves 127 UNUSED)
;   q1  A sd-unk B    sdata, neither name nor text known - the defaultChar fallback
;   q2  A sd-unk2 B   a SECOND unknown one, to pin the fallback by equality
;
; *The two ENTITIES that resolve to a printable ASCII character are used for
; every value the golden prints (excl -> #\! and U-0041 -> #\A), and the
; defaultChar fallback is pinned by COMPARING characters instead of printing
; one: the reference's sgml backend escapes a character its output coding
; system cannot represent as a numeric reference while this port writes UTF-8
; unconditionally, which is the open OutputEncoder item
; and has nothing to do with these node classes.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

(define (p prop nd)
  (if (node-list-empty? nd)
      'EMPTYNL
      (node-property prop (node-list-first nd) null: 'NULLACC default: 'NOTINCL)))

(define (show v)
  (cond ((symbol? v) (symbol->string v))
        ((string? v) (string-append "\"" v "\""))
        ((char? v) (string-append "#\\" (string v)))
        ((number? v) (number->string v))
        ((null? v) "()")
        ((pair? v) (string-append "(" (join v) ")"))
        ((node-list? v) (string-append "NL:" (number->string (node-list-length v))))
        ((equal? v #t) "#t")
        ((equal? v #f) "#f")
        (else "?")))

(define (join l)
  (if (null? l)
      ""
      (string-append (show (car l))
                     (if (null? (cdr l)) "" " ")
                     (join (cdr l)))))

(define (line tag prop nd)
  (out (string-append tag " " (symbol->string prop) "=" (show (p prop nd)))))

; the eleven INTRINSIC_PROPS plus the four axes every class answers
(define (report-intrinsic tag nd)
  (make sequence
    (line tag 'class-name nd)
    (line tag 'children-property-name nd)
    (line tag 'data-property-name nd)
    (line tag 'data-sep-property-name nd)
    (line tag 'origin-to-subnode-rel-property-name nd)
    (line tag 'subnode-property-names nd)
    (line tag 'all-property-names nd)
    (out (string-append tag " parent-cn="
                        (show (p 'class-name (parent (node-list-first nd))))))
    (out (string-append tag " origin-cn="
                        (show (p 'class-name (origin (node-list-first nd))))))
    (out (string-append tag " origin-gi="
                        (show (p 'gi (origin (node-list-first nd))))))
    (out (string-append tag " tree-root-cn="
                        (show (p 'class-name (tree-root (node-list-first nd))))))
    (out (string-append tag " grove-root-cn="
                        (show (p 'class-name (p 'grove-root nd)))))
    (out (string-append tag " data=\"" (data nd) "\""))
    (out (string-append tag " kids=" (number->string (node-list-length (children nd)))))
    (out (string-append tag " preced=" (number->string (node-list-length (preced nd)))
                        " follow=" (number->string (node-list-length (follow nd)))
                        " first-sib=" (show (first-sibling? nd))
                        " last-sib=" (show (last-sibling? nd))))))

; the four properties the entity-reference classes share (plus `char`, which
; only sdata and data-char answer)
(define (report-entref tag nd)
  (make sequence
    (report-intrinsic tag nd)
    (line tag 'char nd)
    (line tag 'system-data nd)
    (line tag 'entity-name nd)
    (line tag 'entity nd)))

; the entity DECLARATION node the reference node points at
(define (report-entity tag e)
  (make sequence
    (line tag 'class-name e)
    (line tag 'name e)
    (line tag 'entity-type e)
    (line tag 'text e)
    (line tag 'external-id e)
    (line tag 'notation-name e)
    (line tag 'notation e)
    (line tag 'defaulted? e)
    (out (string-append tag " origin-cn="
                        (show (p 'class-name (origin (node-list-first e))))))))

; the class names of every member, in order
(define (each-class tag v)
  (if (node-list-empty? v)
      (empty-sosofo)
      (make sequence
        (out (string-append tag " cn=" (show (p 'class-name v))))
        (each-class tag (node-list-rest v)))))

(define (probe ps i) (node-list-ref (children (node-list-ref ps i)) 1))

(define (shape tag nl i)
  (out (string-append "shape " tag " kids="
                      (number->string (node-list-length (children (node-list-ref nl i))))
                      " datalen="
                      (number->string (string-length (data (node-list-ref nl i)))))))

(root
  (let* ((rt (current-node))
         (de (node-property 'document-element rt))
         (ps (select-elements (descendants de) "P"))
         (qs (select-elements (descendants de) "Q"))
         (sd1 (probe ps 0))
         (sduni (probe ps 1))
         (ed (probe ps 2))
         (pe (probe ps 3))
         (sb (probe ps 4))
         (ns (probe ps 5))
         (unk1 (probe qs 0))
         (unk2 (probe qs 1)))
    (make sequence
      ; every paragraph's shape: the reference node is ONE child between the
      ; two data runs, and the paragraph's `data` length shows what it adds
      (shape "p1" ps 0)
      (shape "p2" ps 1)
      (shape "p3" ps 2)
      (shape "p4" ps 3)
      (shape "p5" ps 4)
      (shape "p6" ps 5)
      (shape "q1" qs 0)
      (shape "q2" qs 1)
      (out (string-append "data p1=\"" (data (node-list-ref ps 0)) "\""))
      (out (string-append "data p2=\"" (data (node-list-ref ps 1)) "\""))
      (out (string-append "data p6=\"" (data (node-list-ref ps 5)) "\""))
      (each-class "p1" (children (node-list-ref ps 0)))
      (each-class "p6" (children (node-list-ref ps 5)))

      (report-entref "sd1" sd1)
      (report-entity "sd1.ent" (p 'entity sd1))
      (report-entref "sduni" sduni)
      (report-entref "ed" ed)
      (report-entity "ed.ent" (p 'entity ed))
      (report-entref "pe" pe)
      (report-entity "pe.ent" (p 'entity pe))
      (report-entref "sb" sb)
      (report-entity "sb.ent" (p 'entity sb))
      (report-entref "ns" ns)
      ; the unknown entities: system-data and entity-name are printable, the
      ; CHARACTER is pinned by equality (see the header)
      (line "unk1" 'system-data unk1)
      (line "unk1" 'entity-name unk1)
      (out (string-append "unk1 char-eq-unk2="
                          (show (equal? (p 'char unk1) (p 'char unk2)))))
      (out (string-append "unk1 char-eq-sd1="
                          (show (equal? (p 'char unk1) (p 'char sd1)))))
      (out (string-append "sd1 char-eq-sduni="
                          (show (equal? (p 'char sd1) (p 'char sduni)))))

      ; select-by-class over a paragraph's children resolves the new class
      ; names through the ComponentName table, in both spellings
      (out (string-append "sel sdata="
                          (number->string (node-list-length
                            (select-by-class (children (node-list-ref ps 0)) 'sdata)))))
      (out (string-append "sel external-data="
                          (number->string (node-list-length
                            (select-by-class (children (node-list-ref ps 2)) 'external-data)))))
      (out (string-append "sel extdata="
                          (number->string (node-list-length
                            (select-by-class (children (node-list-ref ps 2)) 'extdata)))))
      (out (string-append "sel subdocument="
                          (number->string (node-list-length
                            (select-by-class (children (node-list-ref ps 4)) 'subdocument)))))
      (out (string-append "sel subdoc="
                          (number->string (node-list-length
                            (select-by-class (children (node-list-ref ps 4)) 'subdoc)))))
      (out (string-append "sel pi="
                          (number->string (node-list-length
                            (select-by-class (children (node-list-ref ps 3)) 'pi)))))

      ; identity: the same view materialized twice is the same node, and two
      ; different reference nodes are not
      (out (string-append "same sd1=" (show (node-list=? sd1 (probe ps 0)))))
      (out (string-append "same ed=" (show (node-list=? ed (probe ps 2)))))
      (out (string-append "same sd1-ed=" (show (node-list=? sd1 ed))))

      ; the RCS spelling of every new class name
      (out (string-append "rcs sd1="
                          (show (node-property 'class-name (node-list-first sd1)
                                               rcs?: #t default: 'NOTINCL))))
      (out (string-append "rcs ed="
                          (show (node-property 'class-name (node-list-first ed)
                                               rcs?: #t default: 'NOTINCL))))
      (out (string-append "rcs sb="
                          (show (node-property 'class-name (node-list-first sb)
                                               rcs?: #t default: 'NOTINCL))))
      (out (string-append "rcs ns="
                          (show (node-property 'class-name (node-list-first ns)
                                               rcs?: #t default: 'NOTINCL)))))))
