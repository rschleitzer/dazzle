; props1.scm - the CLASS METADATA and INTRINSIC node properties.
;
; ASCII ONLY and no angle brackets in comments (the .scm is parsed as SGML).
;
; Every value is minted from the reference C++ dazzle. null: / default: are
; both supplied so the golden DISCRIMINATES the three access results:
;   a value    - accessOK
;   NULLACC    - accessNull
;   NOTINCL    - accessNotInClass (or an unknown property name)
;
; One `report` per NODE CLASS of props.sgml: the grove root, the prolog PI, the
; epilog PI, the document element, a nested element, an EMPTY element (BR), an
; element with a specified CONREF attribute (REF), an element that is an
; INCLUSION of the model (NOTE), and a data-char node. Beyond the property
; values the report also pins what they FEED: `kids`/`desc`/`data` show that the
; children AXIS is class-specific (all three are empty at the grove root, whose
; class has no children property), `rsib` exercises builtins' rsiblings, which
; reads origin-to-subnode-rel-property-name and then THAT property of the
; origin, and the rcs-/byrcs-/upper- lines pin that both component-name
; spellings work in both directions plus the case-insensitive lookup.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

(define (p prop nd)
  (node-property prop (node-list-first nd) null: 'NULLACC default: 'NOTINCL))
(define (pr prop nd)
  (node-property prop (node-list-first nd) rcs?: #t
                 null: 'NULLACC default: 'NOTINCL))

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

(define (report tag nd)
  (make sequence
    (line tag 'class-name nd)
    (line tag 'children-property-name nd)
    (line tag 'data-property-name nd)
    (line tag 'data-sep-property-name nd)
    (line tag 'origin-to-subnode-rel-property-name nd)
    (line tag 'subnode-property-names nd)
    (line tag 'all-property-names nd)
    (line tag 'parent nd)
    (line tag 'content nd)
    (line tag 'gi nd)
    (line tag 'id nd)
    (line tag 'included? nd)
    (line tag 'must-omit-end-tag? nd)
    (line tag 'char nd)
    (line tag 'system-data nd)
    (line tag 'prolog nd)
    (line tag 'epilog nd)
    (line tag 'document-element nd)
    (out (string-append tag " kids=" (number->string (node-list-length (children nd)))))
    (out (string-append tag " desc=" (number->string (node-list-length (descendants nd)))))
    (out (string-append tag " data=\"" (data nd) "\""))
    (out (string-append tag " rsib=" (number->string (node-list-length (rsiblings nd)))))
    (out (string-append tag " rcs-classnm=" (show (pr 'class-name nd))))
    (out (string-append tag " rcs-allpns=" (show (pr 'all-property-names nd))))
    (out (string-append tag " byrcs-classnm=" (show (p 'classnm nd))))
    (out (string-append tag " byrcs-subpns=" (show (p 'subpns nd))))
    (out (string-append tag " upper=" (show (p 'CLASS-NAME nd))))
    (out (string-append tag " bogus=" (show (p 'no-such-property nd))))
    (out (string-append tag " sbc-element=" (sbc nd 'element)))
    (out (string-append tag " sbc-data-char=" (sbc nd 'data-char)))
    (out (string-append tag " sbc-datachar=" (sbc nd 'datachar)))
    (out (string-append tag " sbc-sgmldoc=" (sbc nd 'sgmldoc)))
    (out (string-append tag " sbc-pi=" (sbc nd 'pi)))
    (out (string-append tag " sbc-bogus=" (sbc nd 'no-such-class)))))

; select-by-class resolves its argument through the SAME component-name table,
; so both spellings of a class name work and a non-component yields EMPTY.
(define (sbc nd cls)
  (number->string (node-list-length (select-by-class (children nd) cls))))

(element doc
  (let* ((gr (node-property 'grove-root (current-node)))
         (pl (node-property 'prolog (node-list-first gr) default: (empty-node-list)))
         (el (node-property 'epilog (node-list-first gr) default: (empty-node-list))))
    (make sequence
      (report "GROVEROOT" gr)
      (out (string-append "GROVEROOT prolog-len="
                          (number->string (node-list-length pl))))
      (out (string-append "GROVEROOT epilog-len="
                          (number->string (node-list-length el))))
      (report "PROLOGPI" pl)
      (report "EPILOGPI" el)
      (report "DOCELEM" (current-node))
      (process-children))))
(element title (report "TITLE" (current-node)))
(element em (report "EM" (current-node)))
(element br (report "BR" (current-node)))
(element ref (report "REF" (current-node)))
(element note (report "NOTE" (current-node)))
(element p
  (make sequence
    (report "P" (current-node))
    (report "CHARNODE" (node-list-first (children (current-node))))
    (process-node-list (select-elements (children (current-node)) "em"))
    (process-node-list (select-elements (children (current-node)) "br"))
    (process-node-list (select-elements (children (current-node)) "ref"))))
(default (empty-sosofo))
