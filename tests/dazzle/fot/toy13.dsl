<!doctype style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN" [
<!ENTITY e1 SYSTEM "ext1.dsl" CDATA DSSSL>
<!ENTITY e2 SYSTEM "ext2.dsl" CDATA DSSSL>
]>
<style-sheet>
<style-specification id=main use="ex1 ex2">
<style-specification-body>
(element title (make paragraph
  (literal shared-val)
  (literal " ")
  (literal (fn-one))
  (literal " ")
  (literal (fn-two))))
(element p (make paragraph (literal "main-p ") (process-children)))
</style-specification-body>
</style-specification>
<external-specification id=ex1 document=e1>
<external-specification id=ex2 document=e2 specid=b>
</style-sheet>
