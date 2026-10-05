; exercises the dsssl/builtins.dsl prolog: map + node-list->list over a
; select-elements node-list, apply + string-append, attribute-string.
(root (process-children))
(element SUITE
  (literal
    (apply string-append
      (map (lambda (t) (string-append (attribute-string "ID" t) ","))
           (node-list->list (select-elements (descendants (current-node)) "TEST"))))))
