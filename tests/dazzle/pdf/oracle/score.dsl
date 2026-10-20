<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- scores: 'after, 'through, 'before, a length, score-spaces? #f, a color
     change, a line field in a score, a score across a line break; a
     paragraph background -->
(element doc
  (make simple-page-sequence
    page-width: 150mm page-height: 200mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 11pt line-spacing: 14pt
    (process-children)))
(element p
  (make paragraph
    space-after: 6pt
    background-color: (if (equal? (attribute-string "shade") "yes")
                          (color (color-space "ISO/IEC 10179:1996//Color-Space Family::Device RGB") 0.9 0.9 0.6)
                          #f)
    start-indent: (if (equal? (attribute-string "shade") "yes") 5mm 0pt)
    (process-children)))
(element u (make score type: 'after (process-children)))
(element s (make score type: 'through (process-children)))
(element o (make score type: 'before (process-children)))
(element low (make score type: 3pt (process-children)))
(element gap (make score type: 'after score-spaces?: #f (process-children)))
(element red
  (make sequence
    color: (color (color-space "ISO/IEC 10179:1996//Color-Space Family::Device RGB") 0.8 0 0)
    (process-children)))
(element box (make line-field field-width: 25mm (process-children)))
