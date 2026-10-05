; parse2.scm - sgml-parse's ARGUMENT decode, both variants, one probe per
; element of mgdoc.sgml (a failing decode aborts the WHOLE rule, so each probe
; needs its own).
;
; ASCII ONLY and no angle brackets in comments (the .scm is parsed as SGML).
; Every value and every diagnostic is minted from the reference C++ dazzle.
;
; The OpenJade-prefixed variant (external-procedure) has a BROKEN decode loop
; in the reference - `argv[pos[0] + 1]` for EVERY key, and a two-element
; `lists` indexed up to 2. Its reachable halves are pinned here:
;   * architecture: without active: -> "3rd argument ... not a list", blaming
;     the ARCHITECTURE list although the walked object is the sysid string;
;   * parent: without active: -> the same, blaming the node-list;
;   * active: + architecture: -> the architecture silently takes the ACTIVE
;     names and the parse succeeds.
; NOT pinned: active: + parent:, which writes past `lists` and SEGFAULTS the
; reference (rc 139, measured).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(define xparse (external-procedure "UNREGISTERED::OpenJade//Procedure::sgml-parse"))

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (len g) (number->string (node-list-length g)))
(define (probe) (attribute-string "N" (current-node)))
(define (say tag g) (out (string-append (probe) " " tag "=" (len g))))

(element probes (process-children))

(element e
  (case (probe)
    ; a sysid that cannot be opened: ONE diagnostic, and the cached empty
    ; grove answers the second call without a second open attempt.
    (("1") (say "missing" (sgml-parse "nosuch.sgml")))
    (("2") (say "missing-again" (sgml-parse "nosuch.sgml")))
    ; the ISO variant: active: is a list of strings
    (("3") (say "active-ok" (sgml-parse "mg2.sgml" active: '("lk"))))
    ; ... and the extension takes the same key
    (("4") (say "x-active-ok" (xparse "mg2.sgml" active: '("lk"))))
    ; the extension's architecture: alone walks the SYSID, not the list
    (("5") (say "x-arch" (xparse "mg2.sgml" architecture: '("arch"))))
    ; ... and with active: present it walks the ACTIVE names into it
    (("6") (say "x-both" (xparse "mg2.sgml" active: '("lk") architecture: '("arch"))))
    ; the extension's parent: alone, same broken walk, blaming the node-list
    (("7") (say "x-parent" (xparse "mg2.sgml" parent: (current-node))))
    ; the ISO variant's own errors
    (("8") (say "not-a-string" (sgml-parse 42)))
    (("9") (say "bad-key" (sgml-parse "mg2.sgml" bogus: 1)))
    (("10") (say "active-not-list" (sgml-parse "mg2.sgml" active: 7)))
    (("11") (say "active-not-strings" (sgml-parse "mg2.sgml" active: '(7))))
    (("12") (say "parent-empty" (sgml-parse "mg2.sgml" parent: (empty-node-list))))
    (else (empty-sosofo))))
