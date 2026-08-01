<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; trans3 - the transform backend's OWN classes inside a captured port. A
; `label:`ed child is recorded onto a save queue and replayed when its owner
; flushes, so every one of these calls has to survive the round trip through
; the queue - element brackets, attribute lists, entity refs, PIs and the
; formatting instruction alike. Written ports-first again, so the replay
; order is observable.

(declare-flow-object-class element
  "UNREGISTERED::James Clark//Flow Object Class::element")
(declare-flow-object-class empty-element
  "UNREGISTERED::James Clark//Flow Object Class::empty-element")
(declare-flow-object-class entity-ref
  "UNREGISTERED::James Clark//Flow Object Class::entity-ref")
(declare-flow-object-class processing-instruction
  "UNREGISTERED::James Clark//Flow Object Class::processing-instruction")
(declare-flow-object-class formatting-instruction
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(root (make simple-page-sequence (process-children)))

(element p
  (make element gi: "out"
    (make script
      (make sequence label: 'post-sup
        (make element gi: "sup" attributes: (list (list "k" "v") (list "n" "2"))
          (literal "S")
          (make empty-element gi: "br")
          (make entity-ref name: "amp")
          (make processing-instruction data: "pi-in-port")
          (make formatting-instruction data: "<!-- raw -->")))
      (make sequence label: 'pre-sup
        (make element gi: "pre" (literal "P")))
      (literal "body"))
    ; the same classes in the principal stream, for the contrast
    (make empty-element gi: "hr" attributes: (list (list "w" "1")))
    (make processing-instruction data: "pi-principal")
    (make formatting-instruction data: "<!-- fi -->")
    ; an element whose gi: is empty falls back to the current node's GI
    (make element (literal "gi-from-node"))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
