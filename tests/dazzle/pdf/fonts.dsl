<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<style-sheet>
<style-specification>
<style-specification-body>
(element doc
  (make simple-page-sequence
    page-width: 120mm page-height: 80mm
    left-margin: 10mm right-margin: 10mm top-margin: 10mm bottom-margin: 10mm
    font-family-name: "Tiny" font-size: 12pt line-spacing: 16pt
    center-footer: (make sequence font-family-name: "Nonesuch Sans"
                     (literal "standard: ") (page-number-sosofo))
    (process-children)))
(element p (make paragraph space-before: 4mm (process-children)))
(element b (make sequence font-weight: 'bold (process-children)))
</style-specification-body>
</style-specification>
</style-sheet>
