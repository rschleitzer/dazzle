<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; query1 - the DSSSL QUERY LANGUAGE forms, WITHOUT -2. All four sit in the
; unconditional keys[] table, so they work without the flag; what -2 adds is
; only the `?`-less alias (query2).
;
; SchemeParser::parseSpecialQuery is pure syntax: `(FORM v nl expr)` becomes
; `(PRIM (lambda (v) expr) nl)` with PRIM one of four builtins.dsl
; procedures. What this pins:
;  - the four mappings (there-exists? -> node-list-some?, for-all? ->
;    node-list-every?, select-each -> node-list-filter, union-for-each ->
;    node-list-union-map) and their empty-node-list answers (#f / #t);
;  - the scope: the bound variable is a LAMBDA variable, visible in the
;    EXPRESSION only - the node-list argument still sees the outer binding;
;  - the operator is resolved at PARSE time through
;    Identifier::computeBuiltinValue, so a user redefinition of the four
;    primitives does NOT reach the query forms, while a direct call to the
;    same name does. That is the only reason Identifier carries a builtin
;    shadow at all;
;  - `there-exists` without the `?` is an undefined variable here;
;  - a syntactic keyword as the BOUND VARIABLE, and a query keyword used as
;    an ordinary variable, are both `syntactic keyword ... used as variable`.
;
; A MARKED SECTION, not a SYSTEM .scm entity (see key1.dsl), and pure ASCII:
; this port reads its .dsl as UTF-8 while the reference reads it 8-bit, so a
; non-ASCII byte in a comment is a non-SGML character to onsgmls and not to
; us (the documented input-decoder deviation).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (yn b) (if b "yes" "no"))
(define (num n) (number->string n))
(define (is-gi? x g) (let ((n (gi x))) (and n (string=? n g))))

; --- the four primitives, REDEFINED before every use ----------------------
; A direct call sees these; the query forms must not.
(define (node-list-some? proc nl) "redefined-some")
(define (node-list-every? proc nl) "redefined-every")
(define (node-list-filter proc nl) (empty-node-list))
(define (node-list-union-map proc nl) (empty-node-list))

(root (process-children))

(element doc
  (make sequence
    ; --- there-exists? / for-all? ---------------------------------------
    (out (string-append "te-sec=" (yn (there-exists? x (children (current-node)) (is-gi? x "SEC")))))
    (out (string-append "te-zzz=" (yn (there-exists? x (children (current-node)) (is-gi? x "ZZZ")))))
    (out (string-append "fa-sec=" (yn (for-all? x (children (current-node)) (is-gi? x "SEC")))))
    (out (string-append "fa-nl=" (yn (for-all? x (children (current-node)) (node-list? x)))))
    ; the empty node list: some? is #f, every? is #t
    (out (string-append "te-empty=" (yn (there-exists? x (empty-node-list) #t))))
    (out (string-append "fa-empty=" (yn (for-all? x (empty-node-list) #f))))
    ; --- select-each / union-for-each ------------------------------------
    (out (string-append "se-para=" (num (node-list-length (select-each x (descendants (current-node)) (is-gi? x "PARA"))))))
    (out (string-append "se-all=" (num (node-list-length (select-each x (children (current-node)) #t)))))
    (out (string-append "se-first=" (gi (node-list-first (select-each x (children (current-node)) (is-gi? x "NOTE"))))))
    (out (string-append "ufe=" (num (node-list-length (union-for-each x (children (current-node)) (children x))))))
    (out (string-append "ufe-empty=" (num (node-list-length (union-for-each x (empty-node-list) (children x))))))
    ; --- the direct calls DO see the redefinitions -----------------------
    (out (string-append "direct-some=" (if (string? (node-list-some? car (children (current-node)))) "redefined" "builtin")))
    (out (string-append "direct-filter=" (num (node-list-length (node-list-filter (lambda (y) #t) (children (current-node)))))))
    ; --- scope: the node-list argument sees the OUTER binding ------------
    (out (string-append "scope=" (num (node-list-length (let ((x (children (current-node)))) (select-each x x (is-gi? x "SEC")))))))
    ; --- nesting: the inner bound variable shadows the outer -------------
    (out (string-append "nest=" (yn (there-exists? x (children (current-node))
                                      (there-exists? x (children x) (is-gi? x "TITLE"))))))
    (process-children)))

; --- the `?`-less alias is -2-ONLY (see query2) ---------------------------
(element sec (out (string-append "sec=" (yn (there-exists x (children (current-node)) #t)))))

; --- a syntactic keyword as the BOUND VARIABLE ---------------------------
(element note (out (string-append "note=" (yn (there-exists? if (children (current-node)) #t)))))

; --- a query keyword used as an ordinary variable ------------------------
(define also-a-keyword for-all?)
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
