<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- headers and footers of the region of a page model (ISO/IEC 10179
     12.6.4.1, header-specification and footer-specification): the first
     page has a footer only, without a height (as high as what it generates);
     the pages after it a header with a height, which takes more room than
     its line, and a footer, the page number at the outside, in a model of
     their own each; the flow between them, a column set in it -->
(define (footer-line align)
  (make paragraph quadding: align font-size: 8pt line-spacing: 10pt
    (literal "Seite ") (page-number-sosofo)))
(define (header-line align)
  (make sequence
    (make paragraph quadding: align font-size: 8pt line-spacing: 10pt
      font-posture: 'italic (literal "Kopfzeile des Seitenmodells"))
    (make rule orientation: 'horizontal line-thickness: 0.5pt space-before: 2pt)))
(define-page-model erste
  (width 140mm) (height 160mm)
  (region (x-origin 20mm) (y-origin 15mm) (width 100mm) (height 130mm) (flow #f)
          (footer (generate (footer-line 'center)))))
(define-page-model links
  (width 140mm) (height 160mm)
  (region (x-origin 15mm) (y-origin 15mm) (width 100mm) (height 130mm) (flow #f)
          (header (height 12mm) (generate (header-line 'start)))
          (footer (generate (footer-line 'start)))))
(define-page-model rechts
  (width 140mm) (height 160mm)
  (region (x-origin 25mm) (y-origin 15mm) (width 100mm) (height 130mm) (flow #f)
          (header (height 12mm) (generate (header-line 'end)))
          (footer (generate (footer-line 'end)))))
(define-column-set-model zwei
  (column-subset (balance? #t) (flow ((#f body-text)))
    (column (x-origin 0mm) (width 48mm))
    (column (x-origin 52mm) (width 48mm))))
(element doc
  (make page-sequence
    initial-page-models: (list erste)
    repeat-page-models: (list links rechts)
    font-family-name: "Times New Roman" font-size: 10pt line-spacing: 12pt
    (process-children)))
(element p (make paragraph space-after: 4pt (process-children)))
(element cols
  (make column-set-sequence
    column-set-model: zwei
    space-before: 6pt space-after: 6pt
    (process-children)))
