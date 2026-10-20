<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- letter-spacing (Dazzle.Pdf's extension): wider and narrower, across
     words and a line break, in a justified paragraph with a soft hyphen;
     inline graphics raised and lowered by position-point-shift, a tall one
     that grows its line, and grows-line? #f, which leaves the line as its
     text makes it -->
(declare-characteristic letter-spacing
  "UNREGISTERED::Dazzle//Characteristic::letter-spacing" 0pt)
(declare-characteristic grows-line?
  "UNREGISTERED::Dazzle//Characteristic::grows-line?" #t)
(element doc
  (make simple-page-sequence
    page-width: 150mm page-height: 150mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 11pt line-spacing: 14pt
    (process-children)))
(element p
  (make paragraph
    space-after: 4pt
    quadding: (if (equal? (attribute-string "justify") "yes") 'justify 'start)
    (process-children)))
(element wide (make sequence letter-spacing: 1.5pt (process-children)))
(element tight (make sequence letter-spacing: -0.4pt (process-children)))
(define (points name default)
  (let ((s (attribute-string name)))
    (if s (* (string->number s) 1pt) default)))
(element fig
  (make sequence
    position-point-shift: (points "shift" 0pt)
    grows-line?: (not (equal? (attribute-string "grows") "no"))
    (make external-graphic
      entity-system-id: "figure.png"
      max-height: (points "h" 9pt))))
