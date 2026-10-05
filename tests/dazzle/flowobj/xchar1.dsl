<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; xchar1 - the TeX backend's EXTENSION CHARACTERISTIC table
; (makeTeXFOTBuilder, TeXFOTBuilder.cxx:1830-2000): fifteen entries, of which
; three exist NOWHERE else - `preserve-sdata?` and the two OpenJade-prefixed
; ones, `page-two-side?` and `two-side-start-on-right?`, the only extension
; characteristics whose public id is not in the James Clark namespace.
;
; An extension characteristic that the ACTIVE backend does not know is an
; IgnoredC: accepted anywhere, rendering nothing. So this stylesheet also
; declares one under a made-up public id, to pin that the resolution is by
; public id and not by name.

(declare-characteristic page-number-format
  "UNREGISTERED::James Clark//Characteristic::page-number-format" "1")
(declare-characteristic page-number-restart?
  "UNREGISTERED::James Clark//Characteristic::page-number-restart?" #f)
(declare-characteristic page-n-columns
  "UNREGISTERED::James Clark//Characteristic::page-n-columns" 1)
(declare-characteristic page-column-sep
  "UNREGISTERED::James Clark//Characteristic::page-column-sep" 0pt)
(declare-characteristic page-balance-columns?
  "UNREGISTERED::James Clark//Characteristic::page-balance-columns?" #f)
(declare-characteristic subscript-depth
  "UNREGISTERED::James Clark//Characteristic::subscript-depth" 0pt)
(declare-characteristic over-mark-height
  "UNREGISTERED::James Clark//Characteristic::over-mark-height" 0pt)
(declare-characteristic under-mark-depth
  "UNREGISTERED::James Clark//Characteristic::under-mark-depth" 0pt)
(declare-characteristic superscript-height
  "UNREGISTERED::James Clark//Characteristic::superscript-height" 0pt)
(declare-characteristic grid-row-sep
  "UNREGISTERED::James Clark//Characteristic::grid-row-sep" 0pt)
(declare-characteristic grid-column-sep
  "UNREGISTERED::James Clark//Characteristic::grid-column-sep" 0pt)
(declare-characteristic heading-level
  "UNREGISTERED::James Clark//Characteristic::heading-level" 0)
(declare-characteristic preserve-sdata?
  "UNREGISTERED::James Clark//Characteristic::preserve-sdata?" #f)
(declare-characteristic page-two-side?
  "UNREGISTERED::OpenJade//Characteristic::page-two-side?" #f)
(declare-characteristic two-side-start-on-right?
  "UNREGISTERED::OpenJade//Characteristic::two-side-start-on-right?" #f)
(declare-characteristic made-up
  "UNREGISTERED::nobody//Characteristic::made-up" #f)

(root
  (make simple-page-sequence
    page-two-side?: #t
    two-side-start-on-right?: #t
    page-number-format: "i"
    page-number-restart?: #t
    page-n-columns: 2
    page-column-sep: 18pt
    page-balance-columns?: #t
    heading-level: 3
    made-up: #t
    (process-children)))

(element p
  (make paragraph
    subscript-depth: 2pt
    over-mark-height: 3pt
    under-mark-depth: 4pt
    superscript-height: 5pt
    grid-row-sep: 6pt
    grid-column-sep: 7pt
    preserve-sdata?: #t
    made-up: 9
    (process-children)))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
