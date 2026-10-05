(define if-first-page
  (external-procedure "UNREGISTERED::James Clark//Procedure::if-first-page"))
(define if-front-page
  (external-procedure "UNREGISTERED::James Clark//Procedure::if-front-page"))
(define no-such
  (external-procedure "UNREGISTERED::James Clark//Procedure::no-such-thing"))
(element doc (make simple-page-sequence
  center-header: (if-first-page
    (empty-sosofo)
    (make sequence (literal "Doc ") (page-number-sosofo)))
  left-footer: (if-front-page
    (literal "front")
    (literal "back"))
  right-footer: (if-first-page
    (if-front-page (literal "ff") (literal "fb"))
    (if-front-page (literal "of") (literal "ob")))
  center-footer: (if no-such (literal "?") (current-node-page-number-sosofo))
  (process-children)))
(element title (make paragraph (process-children)))
(element p (make paragraph (process-children)))
(element em (make sequence (process-children)))
