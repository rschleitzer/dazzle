<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; addr2 - the DIAGNOSTIC side of the address family. One probe per element,
; because a primitive argError kills the whole construction rule: two probes
; in one rule and the second is never reached.

; forced outside any node: current-node-address and hytime-linkend are the
; two producers with no argument to check first, so noCurrentNode is the
; only diagnostic they can raise.
(define no-node (current-node-address))
(define no-node2 (hytime-linkend))

(define (p x) (make sequence (literal (if x "y" "n"))))

(root (make simple-page-sequence (process-children)))
(element doc (process-children))

; --- not an address ---------------------------------------------------
(element a (p (address-local? "alpha")))
(element b (p (address-visited? 5)))
; #f is NOT an address either - the link characteristic maps it to
; Address::none, but the predicate does not.
(element c (p (address-local? #f)))

; --- not a string -----------------------------------------------------
(element d (p (address? (idref-address 5))))
(element e (p (address? (entity-address #f))))
(element f (p (address? (sgml-document-address 5 "s"))))
(element g (p (address? (sgml-document-address "s" 5))))

; --- not a singleton node ---------------------------------------------
(element h (p (address? (node-list-address "alpha"))))
(element i (p (address? (node-list-address (empty-node-list)))))

; --- no current node --------------------------------------------------
(element j (p (address? no-node)))
(element k (p (address? no-node2)))

(default (empty-sosofo))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
