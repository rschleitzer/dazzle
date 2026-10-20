<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- a document longer than a read block (8192 bytes) read after xml.dcl, so
     its storage objects are merged and split at block bounds: under wasm the
     file system gives no block size, and a step of 0 once grew the bounds
     until memory ran out; over pages with the page number in the footer -->
(element doc
  (make simple-page-sequence
    page-width: 140mm page-height: 160mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 20mm
    footer-margin: 8mm
    font-family-name: "Times New Roman" font-size: 10pt line-spacing: 12pt
    center-footer: (make sequence (literal "Seite ") (page-number-sosofo))
    (process-children)))
(element p (make paragraph space-after: 4pt (process-children)))
