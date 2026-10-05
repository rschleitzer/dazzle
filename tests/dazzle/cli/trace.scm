(define (classify x)
    (case x
        (("a") "alpha")
        (("b") "beta")))

(define (walk items)
    (apply string-append (map classify items)))

(root (literal (walk (list "a" "z"))))
