<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- display and inline boxes: a display box is set as a group of blocks
     (never as a column set), an inline box inside its line; the shape of the
     DocBook print stylesheet's warning and caution -->
(element doc
  (make simple-page-sequence
    page-width: 150mm page-height: 120mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 11pt line-spacing: 14pt
    (process-children)))
(element p
  (make paragraph space-after: 6pt (process-children)))
(element b
  (make box font-weight: 'bold (process-children)))
(element warning
  (make display-group
    space-before: 9pt space-after: 9pt
    (make box
      display?: #t
      box-type: 'border
      line-thickness: 2pt
      start-indent: 12pt
      (make paragraph
        font-family-name: "Arial" font-weight: 'bold font-size: 13pt line-spacing: 16pt
        quadding: 'center
        keep-with-next?: #t
        (literal "Warning"))
      (process-children))))
