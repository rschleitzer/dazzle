; props4.scm - `application-info`, the one sgml-document property that needs an
; SGML DECLARATION to be non-null (appinfo.sgml carries APPINFO "the app info";
; every other fixture document uses the reference declaration, where APPINFO is
; NONE and the property is accessNull - see props3).
;
; ASCII ONLY and no angle brackets in comments (the .scm is parsed as SGML).

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
        ((number? v) (number->string v))
        ((node-list? v) (string-append "NL:" (number->string (node-list-length v))))
        ((equal? v #t) "#t")
        ((equal? v #f) "#f")
        (else "?")))

(define (line tag prop nd)
  (out (string-append tag " " (symbol->string prop) "=" (show (p prop nd)))))

(root (process-children))

(element doc
  (let* ((rt (node-property 'grove-root (current-node))))
    (make sequence
      (line "root" 'application-info rt)
      (line "root" 'sgml-constants rt)
      (line "root" 'entities rt)
      (line "root" 'defaulted-entities rt)
      (line "root" 'elements rt)
      (out (string-append "root.dt-name="
                          (show (p 'name (p 'governing-doctype rt)))))
      (out (string-append "root.el-types="
                          (show (p 'element-types (p 'governing-doctype rt))))))))
