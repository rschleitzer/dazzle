<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; query5 - the RECOVERY model of the top-level loop (SchemeParser.cxx:114),
; the second thing the query fixtures uncovered.
;
; The loop NEVER skips a failed form. It raises `recovering` and reads on
; TOKEN BY TOKEN with every token allowed, so a `(` plus a keyed identifier
; sitting inside the wreckage is parsed as a top-level form in its own right:
; `(bogus (define hidden ...))` really does define hidden, and the leftover
; `)` afterwards is an `unexpected token` of its own. Only the three
; deliberately ignored declarations - declare-reference-value-type,
; define-page-model, define-column-set-model - call skipForm.
;
; The `recovering` flag suppresses only the `unknown top level form`
; DIAGNOSTIC, never the parse: the second bogus form below is silent, but the
; construction rule buried in it is installed all the same.
;
; Pure ASCII, marked section - see query1.dsl.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

; the nested define survives the unknown form; the trailing `)` does not
(bogus (define hidden "found-inside"))

; and a construction rule buried in a SILENT (recovering) unknown form is
; installed just the same
(alsobogus (element em (out "em-from-wreckage")))

(root (process-children))
(element doc (process-children))
(element sec (process-children))
(element sub (process-children))
(element note (process-children))
(element title (out (string-append "title=" hidden)))
(element para (process-children))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
