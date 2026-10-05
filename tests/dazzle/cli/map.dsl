; a simple transform stylesheet exercising make element + attributes,
; multi-line with comments to verify LF->RE record normalization.
(declare-flow-object-class element
  "UNREGISTERED::James Clark//Flow Object Class::element")
(root (process-children))
(element DOC (make element gi: "doc" (process-children)))
(element PARA (make element gi: "p" attributes: (list (list "class" "para")) (process-children)))
(element EMPH (make element gi: "em" (process-children)))
