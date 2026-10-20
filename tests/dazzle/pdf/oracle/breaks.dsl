<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- where a line may break: soft hyphens, hyphens between letters (also
     across runs), zero width spaces, white space across runs; verbatim text
     with tabs, wrapping or not; line fields aligned in their width -->
(element doc
  (make simple-page-sequence
    page-width: 150mm page-height: 200mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 11pt line-spacing: 14pt
    (process-children)))
(element p
  (make paragraph
    space-after: 6pt
    end-indent: (if (equal? (attribute-string "width") "narrow") 45mm 0pt)
    (process-children)))
(element em (make sequence font-posture: 'italic (process-children)))
(element code
  (make paragraph
    font-family-name: "Courier New" font-size: 9pt line-spacing: 11pt
    space-after: 6pt
    input-whitespace-treatment: 'preserve
    lines: (if (equal? (attribute-string "lines") "asis") 'asis 'wrap)
    (process-children)))
(element fields (make paragraph (process-children)))
(element field
  (let ((a (attribute-string "align")))
    (make line-field
      field-width: 30mm
      field-align: (cond ((equal? a "end") 'end) ((equal? a "center") 'center) (else 'start))
      (process-children))))
