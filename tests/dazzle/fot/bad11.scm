(define (f a #!optional b) (if b (number->string b) (number->string a)))
(define (k a #!key x) (if x (number->string x) (number->string a)))
(element doc (make display-group (process-children)))
(element title (make paragraph
  (literal (f))))
(element p (make paragraph
  (literal (f 1 2 3))
  (literal " ")
  (literal (k 1 x:))
  (literal " ")
  (literal (k 1 z: 5))
  (literal " ")
  (literal (k 1 2 3))))
(element em (make sequence (process-children)))
