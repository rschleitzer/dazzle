<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; query2 - the same query language WITH -2. The four forms themselves are
; unconditional (query1 runs them without the flag); what the flag adds is
; the `?`-less ALIAS of installSyntacticKey, which turns `there-exists` and
; `for-all` into the very same keys - so here they PARSE as query forms and
; are `syntactic keyword ... used as variable` in variable position, both of
; which are plain undefined variables without the flag.
;
; This also pins that the alias is an alias and not a copy: the aliased form
; desugars to the same builtin operator, so the redefinition of
; node-list-some? is invisible to it too.
;
; Pure ASCII, marked section - see query1.dsl.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (yn b) (if b "yes" "no"))
(define (num n) (number->string n))
(define (is-gi? x g) (let ((n (gi x))) (and n (string=? n g))))

(define (node-list-some? proc nl) "redefined-some")
(define (node-list-every? proc nl) "redefined-every")

(root (process-children))

(element doc
  (make sequence
    (out (string-append "alias-te=" (yn (there-exists x (children (current-node)) (is-gi? x "SEC")))))
    (out (string-append "alias-te-no=" (yn (there-exists x (children (current-node)) (is-gi? x "ZZZ")))))
    (out (string-append "alias-fa=" (yn (for-all x (children (current-node)) (is-gi? x "SEC")))))
    (out (string-append "alias-fa-nl=" (yn (for-all x (children (current-node)) (node-list? x)))))
    ; the `?` spellings keep working under the flag
    (out (string-append "te=" (yn (there-exists? x (children (current-node)) (is-gi? x "NOTE")))))
    (out (string-append "se=" (num (node-list-length (select-each x (children (current-node)) (is-gi? x "SEC"))))))
    (out (string-append "ufe=" (num (node-list-length (union-for-each x (children (current-node)) (children x))))))
    ; the direct call still sees the redefinition
    (out (string-append "direct-some=" (if (string? (node-list-some? car (children (current-node)))) "redefined" "builtin")))))

; the alias names are KEYS here, so this is the keyword diagnostic and not
; an undefined variable
(define alias-as-variable there-exists)
(define alias-as-variable2 for-all)
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
