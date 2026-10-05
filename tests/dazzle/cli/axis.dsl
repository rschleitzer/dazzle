; the sibling/axis primitives surfaced by the reproduction sweep:
; children over a MULTI-node list (reference Children self-maps), id,
; node-list-reverse, node-list=?, first-sibling?, last-sibling?,
; child-number, node-list-map.
(root (process-children))
(element SUITE
  (let* ((tests (select-elements (descendants (current-node)) "TEST"))
         (t2 (node-list-first (node-list-rest tests)))
         (grps (children (current-node)))
         (all (children grps)))
    (literal
      (string-append
        (number->string (node-list-length all)) ","
        (if (node-list=? all tests) "=" "!") ","
        (id (node-list-first (node-list-reverse tests))) ","
        (if (first-sibling? (element-with-id "A")) "F" "f") ","
        (if (first-sibling? t2) "F" "f") ","
        (if (last-sibling? t2) "L" "l") ","
        (number->string (child-number t2)) ","
        (number->string (node-list-length (node-list-map (lambda (snl) (parent snl)) tests)))))))
