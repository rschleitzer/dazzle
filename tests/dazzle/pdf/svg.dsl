<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<style-sheet>
<style-specification>
<style-specification-body>
;; An external graphic that is SVG (drawing.svg): its rect (fill, stroke),
;; circle (filled and drawn, drawn alone), line, text and tspan (size, dy, text-anchor, a font-family list whose
;; first family no file has, character and entity references) drawn as the
;; page's own operations at the size the graphic is set at -- half as wide
;; again as its own; its style element passed over.
(element doc
  (make simple-page-sequence
    page-width: 120mm page-height: 80mm
    left-margin: 10mm right-margin: 10mm top-margin: 10mm bottom-margin: 10mm
    font-family-name: "Tiny" font-size: 10pt line-spacing: 14pt
    (process-children)))
(element p (make paragraph space-before: 2mm (process-children)))
(element fig
  (make external-graphic
    display?: #t
    display-alignment: 'center
    entity-system-id: "drawing.svg"
    max-width: 75mm
    scale: 'max-uniform))
</style-specification-body>
</style-specification>
</style-sheet>
