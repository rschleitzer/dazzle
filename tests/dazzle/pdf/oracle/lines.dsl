<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- the height of a line and where its baseline lies: exact, at least,
     min-leading, min-post-line-spacing, min-pre-line-spacing, raised and
     lowered text, a page break at the foot of the area -->
(define (rule) (attribute-string "rule"))
(element doc
  (make simple-page-sequence
    page-width: 150mm page-height: 120mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 11pt line-spacing: 14pt
    (process-children)))
(element p
  (let ((r (rule)))
    (make paragraph
      space-after: 6pt
      line-spacing: (cond ((equal? r "least") 10pt) (else 14pt))
      min-leading: (cond ((equal? r "least") 0pt) ((equal? r "leading") 2pt) (else #f))
      min-post-line-spacing: (if (equal? r "post") 5pt #f)
      min-pre-line-spacing: (if (equal? r "pre") 11pt #f)
      (process-children))))
(element big (make sequence font-family-name: "Arial" font-size: 18pt (process-children)))
(element up (make sequence font-size: 8pt position-point-shift: 4pt (process-children)))
(element down (make sequence font-size: 8pt position-point-shift: -3pt (process-children)))
