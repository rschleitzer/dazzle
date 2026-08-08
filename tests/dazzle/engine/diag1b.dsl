<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
(root (process-children))
(element doc (process-children))
(element p (literal (letrec ((pp (lambda () qq)) (qq (pp))) "x")))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
