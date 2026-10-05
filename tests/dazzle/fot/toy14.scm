; the four primitives the DocBook HTML stylesheets reach for (round /
; select-by-class / follow / entity-system-id) + the pi system-data property.
(element doc (make sequence (process-children)))
(element title (make paragraph
  (literal
    "round: " (number->string (round 2.5))     ; half-to-EVEN, not 3
    " " (number->string (round 3.5))
    " " (number->string (round -2.5))
    " " (number->string (round -3.5))
    " " (number->string (round 2.4))
    " " (number->string (round 2.6))
    " " (number->string (round 7))             ; exact integer, unchanged
    " " (number->string (round 0.5)))))
(element p (make paragraph
  (literal
    "class: " (number->string (node-list-length
                (select-by-class (children (parent (current-node))) 'element)))
    " " (number->string (node-list-length
          (select-by-class (children (parent (current-node))) 'data-char)))
    " " (number->string (node-list-length
          (select-by-class (children (parent (current-node))) 'pi)))
    " " (number->string (node-list-length
          (select-by-class (children (parent (current-node))) 'sgml-document)))
    " " (number->string (node-list-length
          (select-by-class (children (parent (current-node))) 'not-a-class)))
    " axes: " (number->string (node-list-length (follow (current-node))))
    "/" (number->string (node-list-length (preced (current-node))))
    " follow-of-children: "
    (number->string (node-list-length (follow (children (parent (current-node))))))
    " ent: " (let ((v (entity-system-id "nosuchentity"))) (if v v "#f")))))
(element em (make sequence (process-children)))
