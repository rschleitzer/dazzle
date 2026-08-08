<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
(root (process-children))
(element doc (process-children))
(define zz (+ zz 1))
(element p (literal (number->string zz)))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
