<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
(define-language lat (toupper (#\a #\A)) (tolower (#\A #\a) (#\B #\b)))
(declare-default-language lat)
(root (process-children))
(element suite (make sequence
  (literal "N:") (process-children)
  (literal " M:") (with-mode alt (process-children))
  (literal " C:") (literal (string (char-downcase #\B) (char-upcase #\a)))))
(element grp (process-children))
(element test (empty-sosofo))
(element (grp test) (literal "q"))
(mode alt
  (default (process-children))
  (element test (literal "t")))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
