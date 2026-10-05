<!doctype style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<style-sheet>
<style-specification id=one use=local1>
<style-specification-body>
(define shared-val "from-ext1")
(define (fn-one) (string-append "one:" local-helper))
(element em (make sequence (literal "ext1-em ") (process-children)))
(element p (make paragraph (literal "ext1-p")))
</style-specification-body>
</style-specification>
<style-specification id=local1>
<style-specification-body>
(define local-helper "L1")
</style-specification-body>
</style-specification>
</style-sheet>
