; props2.scm - the ATTRIBUTE axis: the `attributes` named-node-list and the
; attribute-assignment / attribute-value-token / attribute-def node classes.
;
; ASCII ONLY and no angle brackets in comments (the .scm is parsed as SGML).
;
; Every value is minted from the reference C++ dazzle. null: / default: are
; both supplied so the golden DISCRIMINATES the three access results:
;   a value    - accessOK
;   NULLACC    - accessNull
;   NOTINCL    - accessNotInClass (or an unknown property name)

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

(define (p prop nd)
  (node-property prop (node-list-first nd) null: 'NULLACC default: 'NOTINCL))

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

; the attributes property, both ways in: the named-node-list primitive and the
; property of the same name.
(define (attrs nd) (attributes nd))
(define (att nd name) (named-node name (attributes nd)))

; ---- one report per attribute-assignment --------------------------------
(define (report-assign tag nd)
  (make sequence
    (line tag 'class-name nd)
    (line tag 'name nd)
    (line tag 'implied? nd)
    (line tag 'token-sep nd)
    (line tag 'value nd)
    (line tag 'attribute-def nd)
    (line tag 'children-property-name nd)
    (line tag 'data-property-name nd)
    (line tag 'data-sep-property-name nd)
    (line tag 'origin-to-subnode-rel-property-name nd)
    (line tag 'subnode-property-names nd)
    (line tag 'all-property-names nd)
    (line tag 'parent nd)
    (out (string-append tag " origin-cn="
                        (show (p 'class-name (origin (node-list-first nd))))))
    (out (string-append tag " origin-gi="
                        (show (p 'gi (origin (node-list-first nd))))))
    (out (string-append tag " data=\"" (data nd) "\""))
    (out (string-append tag " kids="
                        (number->string (node-list-length (children nd)))))
    (out (string-append tag " desc="
                        (number->string (node-list-length (descendants nd)))))
    (out (string-append tag " preced="
                        (number->string (node-list-length (preced nd)))))
    (out (string-append tag " follow="
                        (number->string (node-list-length (follow nd)))))
    (out (string-append tag " child-num="
                        (show (child-number (node-list-first nd)))))
    (out (string-append tag " first-sib=" (show (first-sibling? nd))))
    (out (string-append tag " last-sib=" (show (last-sibling? nd))))
    (out (string-append tag " abs-first-sib="
                        (show (absolute-first-sibling? nd))))
    (out (string-append tag " tree-root-cn="
                        (show (p 'class-name (tree-root (node-list-first nd))))))))

; ---- one report per attribute-value-token -------------------------------
(define (report-token tag nd)
  (make sequence
    (line tag 'class-name nd)
    (line tag 'token nd)
    (line tag 'entity nd)
    (line tag 'notation nd)
    (line tag 'referent nd)
    (line tag 'all-property-names nd)
    (line tag 'data-property-name nd)
    (line tag 'parent nd)
    (out (string-append tag " origin-cn="
                        (show (p 'class-name (origin (node-list-first nd))))))
    (out (string-append tag " parent-cn="
                        (show (p 'class-name (parent (node-list-first nd))))))
    (out (string-append tag " data=\"" (data nd) "\""))
    (out (string-append tag " preced="
                        (number->string (node-list-length (preced nd)))))
    (out (string-append tag " follow="
                        (number->string (node-list-length (follow nd)))))))

; ---- the named-node-list itself -----------------------------------------
(define (report-nnl tag nl)
  (make sequence
    (out (string-append tag " len=" (number->string (node-list-length nl))))
    (out (string-append tag " nnl?=" (show (named-node-list? nl))))
    (out (string-append tag " names=" (show (named-node-list-names nl))))
    (out (string-append tag " norm-id=\""
                        (named-node-list-normalize "id" nl 'general) "\""))
    (out (string-append tag " norm-ID=\""
                        (named-node-list-normalize "ID" nl 'general) "\""))))

; The reports run from the DOC construction rule, so `d` is the current node
; and the probed children are selected from it (props1 does the same).
(element doc
  (let* ((d (current-node))
         (ps (select-elements (children d) "p"))
         (fs (select-elements (children d) "fig"))
         (p1 (node-list-ref ps 0))
         (p2 (node-list-ref ps 1))
         (f1 (node-list-ref fs 0))
         (f2 (node-list-ref fs 1)))
    (make sequence
      ; the named-node-list of every probed element
      (report-nnl "doc-nnl" (attrs d))
      (report-nnl "p1-nnl" (attrs p1))
      (report-nnl "f1-nnl" (attrs f1))
      (report-nnl "f2-nnl" (attrs f2))
      ; DOC: a specified CDATA, an unspecified #IMPLIED, a defaulted CDATA,
      ; a defaulted enumeration and a #FIXED
      (report-assign "doc-lang" (att d "LANG"))
      (report-assign "doc-version" (att d "VERSION"))
      (report-assign "doc-state" (att d "STATE"))
      (report-assign "doc-fixed" (att d "FIXED"))
      ; P: ID, IDREFS (two tokens), NMTOKENS (three), NUMBER, #CURRENT
      (report-assign "p1-id" (att p1 "ID"))
      (report-assign "p1-refs" (att p1 "REFS"))
      (report-assign "p1-words" (att p1 "WORDS"))
      (report-assign "p1-n" (att p1 "N"))
      (report-assign "p1-kind" (att p1 "KIND"))
      (report-assign "p2-kind" (att p2 "KIND"))
      ; FIG: ENTITY, ENTITIES (two), NOTATION
      (report-assign "f1-file" (att f1 "FILE"))
      (report-assign "f1-more" (att f1 "MORE"))
      (report-assign "f1-form" (att f1 "FORM"))
      (report-assign "f2-more" (att f2 "MORE"))
      (report-assign "f2-form" (att f2 "FORM"))
      ; the VALUE node-lists: one token report per member
      (report-token "p1-refs-t0" (node-list-ref (p 'value (att p1 "REFS")) 0))
      (report-token "p1-refs-t1" (node-list-ref (p 'value (att p1 "REFS")) 1))
      (report-token "p1-words-t0" (node-list-ref (p 'value (att p1 "WORDS")) 0))
      (report-token "p1-id-t0" (node-list-ref (p 'value (att p1 "ID")) 0))
      (report-token "f1-file-t0" (node-list-ref (p 'value (att f1 "FILE")) 0))
      (report-token "f1-more-t1" (node-list-ref (p 'value (att f1 "MORE")) 1))
      (report-token "f1-form-t0" (node-list-ref (p 'value (att f1 "FORM")) 0))
      ; a CDATA value is a data-char run, not a token
      (report-token "doc-lang-v0" (node-list-ref (p 'value (att d "LANG")) 0))
      ; and the string-shaped accessors over the same ground
      (out (string-append "attr-string lang="
                          (show (attribute-string "LANG" d))))
      (out (string-append "attr-string version="
                          (show (attribute-string "VERSION" d))))
      (out (string-append "attr-string absent="
                          (show (attribute-string "NOSUCH" d))))
      (out (string-append "p1 refs-string=" (show (attribute-string "REFS" p1))))
      (out (string-append "f1 file-string="
                          (show (attribute-string "FILE" f1)))))))
(default (empty-sosofo))
