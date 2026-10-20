<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- line heights as a word processor's (Dazzle.Pdf 0.10.0): text-line-height
     and text-descent give a run the line height and descent it needs instead
     of its font's; line-height-factor sets every line of a paragraph as high
     as its own text needs times the factor, the rest below the placement
     path: with min-leading and without a factor, with factors of 1000,
     1150, 1500 and 2000, a taller run, a deeper one, a larger font, an
     inline graphic, and a paragraph running past the end of a page -->
(declare-characteristic text-line-height
  "UNREGISTERED::Dazzle//Characteristic::text-line-height" 0pt)
(declare-characteristic text-descent
  "UNREGISTERED::Dazzle//Characteristic::text-descent" 0pt)
(declare-characteristic line-height-factor
  "UNREGISTERED::Dazzle//Characteristic::line-height-factor" 0)
(element doc
  (make simple-page-sequence
    page-width: 120mm page-height: 90mm
    left-margin: 15mm right-margin: 15mm top-margin: 12mm bottom-margin: 12mm
    font-family-name: "Arial" font-size: 10pt line-spacing: 12pt
    (process-children)))
(element p
  (let ((f (attribute-string "factor")))
    (make paragraph space-after: 4pt
      min-leading: (if (attribute-string "least") 0pt #f)
      line-height-factor: (if f (string->number f) 0)
      (process-children))))
(element tall (make sequence text-line-height: 16pt (process-children)))
(element deep (make sequence text-descent: 6pt (process-children)))
(element big (make sequence font-size: 16pt font-family-name: "Times New Roman" (process-children)))
(element fig (make external-graphic entity-system-id: "figure.png" display?: #f scale: 0.2))
