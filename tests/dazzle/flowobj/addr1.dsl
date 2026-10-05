<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; addr1 - the VALUE side of the address family: the seven producers, what
; address? says about each of them, and how address-local? and
; address-visited? classify every one of the six reachable types.

(define (yn x) (if x "y" "n"))

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence

    ; --- address? over every producer plus two non-addresses --------------
    (literal "is:")
    (literal (yn (address? (current-node-address))))
    (literal (yn (address? (idref-address "alpha"))))
    (literal (yn (address? (entity-address "pic"))))
    (literal (yn (address? (sgml-document-address "sys" "id"))))
    (literal (yn (address? (hytime-linkend))))
    (literal (yn (address? (node-list-address (current-node)))))
    (literal (yn (address? "alpha")))
    (literal (yn (address? #f)))

    ; --- address-local? ---------------------------------------------------
    ; a resolved node is local when it shares the current node's grove, an
    ; idref always is, an entity reference never is, and everything else
    ; falls off the end of the switch.
    (literal " local:")
    (literal (yn (address-local? (current-node-address))))
    (literal (yn (address-local? (node-list-address (current-node)))))
    (literal (yn (address-local? (idref-address "alpha"))))
    (literal (yn (address-local? (idref-address "no-such-id"))))
    (literal (yn (address-local? (entity-address "pic"))))
    (literal (yn (address-local? (sgml-document-address "sys" "id"))))
    (literal (yn (address-local? (hytime-linkend))))

    ; --- address-visited? -------------------------------------------------
    ; the reference has no visited history and answers #f for every type.
    (literal " vis:")
    (literal (yn (address-visited? (current-node-address))))
    (literal (yn (address-visited? (idref-address "alpha"))))
    (literal (yn (address-visited? (sgml-document-address "sys" "id"))))

    ; --- identity ----------------------------------------------------------
    ; each call allocates a fresh object, so `equal?` - which knows nothing
    ; about addresses and falls through to pointer identity - says no even
    ; for two addresses of the same node.
    (literal " eq:")
    (literal (yn (equal? (current-node-address) (current-node-address))))

    ; --- an address bound to a variable stays one -------------------------
    (literal " misc:")
    (let ((a (current-node-address)))
      (make sequence
        (literal (yn (address? a)))
        (literal (yn (address-local? a)))))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
