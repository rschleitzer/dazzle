<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; inline3b (-t tex) - the ONE case in this family where the reference binary
; dies: a character whose `script` property answers #f. TeXFOTBuilder's
; setCharacterNIC writes the script id as `nic.script+29` - pointer arithmetic
; meant to strip the "ISO/IEC 10179::1996//Script::" prefix - and a #f script
; is a NULL PublicId, so the reference reads from address 29 and SEGFAULTS
; (measured: rc 139, EXC_BAD_ACCESS). The characters below are outside every
; range of the built-in script table.
;
; This golden is therefore OUR behaviour: an EMPTY \Script value, the same
; choice this port already made for a #f public-id characteristic
; (TeXFOTBuilder.set_pubid). The fot dump of the very same makes is in
; inline1's family and matches the reference exactly - only the TeX backend's
; pointer trick is unportable.

(root (make simple-page-sequence (process-children)))

(element p
  (make sequence
    (make character char: #\U-2028)
    (make character char: #\U-FFFF)))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
