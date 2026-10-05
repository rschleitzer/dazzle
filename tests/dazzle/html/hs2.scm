(declare-characteristic scroll-title
  "UNREGISTERED::James Clark//Characteristic::scroll-title" "")
(element doc (make sequence (process-children)))
(element title
  (make scroll
    scroll-title: "First"
    (make paragraph
      (make link destination: (node-list-address (element-with-id "FIRST")) (literal "to p")))))
(element p
  (make scroll
    (make paragraph quadding: 'end (process-children))))
(element em (make sequence font-posture: 'italic (process-children)))
