<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; query3 - every way a query form can be malformed, one per line, so the
; recovery of one does not eat the next. parseSpecialQuery has no diagnostic
; of its own beyond the keyword-as-variable one: everything else comes out of
; the shared getToken / skipForm machinery, which is exactly why it is worth
; pinning - the shapes (which token is named, how often `missing closing
; parenthesis` fires, when the form is skipped) are the contract.
;
; Pure ASCII, marked section - see query1.dsl.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

; --- nothing at all, then a partial argument list ------------------------
(define (e1 n) (there-exists?))
(define (e2 n) (for-all? x))
(define (e3 n) (select-each x (children n)))
; --- one argument too many ------------------------------------------------
(define (e4 n) (union-for-each x (children n) (children x) extra))
; --- the bound variable is not an identifier ------------------------------
(define (e5 n) (there-exists? (a b) (children n) #t))
(define (e6 n) (there-exists? 42 (children n) #t))
(define (e7 n) (select-each #t (children n) #t))
; --- the bound variable is a syntactic keyword: a diagnostic, but the form
; --- is still built and still works
(define (e8 n) (there-exists? make (children n) #t))
; --- a query form as a TOP-LEVEL form -------------------------------------
(there-exists? x (empty-node-list) #t)

(root (process-children))
(element doc (out "done"))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
