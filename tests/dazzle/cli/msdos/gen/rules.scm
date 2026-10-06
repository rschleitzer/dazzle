(declare-flow-object-class formatting-instruction "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(element doc (make formatting-instruction data: (apply string-append (map (lambda (s) (string-append s "!")) (list "from" "rules")))))
