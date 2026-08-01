; The transform sink's SECOND stream: an entity flow object writes its own
; file, with its own EncodeOutputCharStream - so the byte-order mark of a
; BOM-writing system is stamped per FILE, not per run.
(declare-flow-object-class entity
  "UNREGISTERED::James Clark//Flow Object Class::entity")
(declare-flow-object-class element
  "UNREGISTERED::James Clark//Flow Object Class::element")
(root (make sequence (process-children)))
(element doc
  (make entity
    system-id: "part.out"
    (make element gi: "p"
      (literal "[\U-20AC]")
      (process-children))))
