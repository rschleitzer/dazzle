; mg1.scm - the GROVE INDEX in the backend's element names. Every reference
; backend prefixes a NON-document grove's index to the anchor / destination
; name it writes (SgmlFOTBuilder::outputElementName - grove 0 writes the bare
; name). sgml-parse is what puts a second grove in reach; the first LOADED
; grove is index 2, because the document grove's own groveTable_ entry has
; already been counted.
;
; ASCII ONLY and no angle brackets in comments (the .scm is parsed as SGML).

(define g1 (node-list-first (sgml-parse "mgsub.sgml")))
(define g2 (node-list-first (sgml-parse "mgsub2.sgml")))

(root
  (make simple-page-sequence
    (let* ((s1 (node-list-first (children (node-property 'document-element g1))))
           (s2 (node-list-first (children (node-property 'document-element g2))))
           (d1 (node-list-first (children (node-property 'document-element (current-node))))))
      (make sequence
        ; a resolved-node link into each grove, and one into the document's own
        (make paragraph (make link destination: (node-list-address s1) (literal "to-2")))
        (make paragraph (make link destination: (node-list-address s2) (literal "to-3")))
        (make paragraph (make link destination: (node-list-address d1) (literal "to-0")))
        ; an idref address carries its own grove too
        (make paragraph (make link destination: (idref-address "s1") (literal "idref")))
        ; and the pending ANCHORS a processed node of a loaded grove leaves:
        ; startNode names it the same way (by ID when it has one, else by
        ; element index), grove prefix and all.
        (make paragraph (with-mode #f (process-node-list s1)))
        (make paragraph (with-mode #f (process-node-list (node-list-rest (children (node-property 'document-element g1))))))))))
