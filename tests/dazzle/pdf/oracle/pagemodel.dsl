<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- the page model (ISO/IEC 10179 12.6.4, 12.6.5; the part openjade-net and
     Dazzle.Pdf set): a page-sequence whose first page has its own model
     with a smaller region, then two models in turn, one of another size;
     column-set-sequences with a balanced two-column model, a column break
     in one of them -->
(define-page-model erste
  (width 140mm) (height 160mm)
  (region (x-origin 25mm) (y-origin 20mm) (width 95mm) (height 100mm) (flow #f)))
(define-page-model gerade
  (width 140mm) (height 160mm)
  (region (x-origin 20mm) (y-origin 15mm) (width 100mm) (height 130mm) (flow #f)))
(define-page-model breit
  (width 150mm) (height 160mm)
  (region (x-origin 15mm) (y-origin 15mm) (width 120mm) (height 130mm)
          (filling-direction 'top-to-bottom) (flow #f)))
(define-column-set-model zwei
  (column-subset (balance? #t) (flow ((#f body-text)))
    (column (x-origin 0mm) (width 46mm))
    (column (x-origin 50mm) (width 46mm))))
(element doc
  (make page-sequence
    initial-page-models: (list erste)
    repeat-page-models: (list gerade breit)
    font-family-name: "Times New Roman" font-size: 10pt line-spacing: 12pt
    (process-children)))
(element p (make paragraph space-after: 4pt (process-children)))
(element brk (make paragraph break-before: 'column))
(element cols
  (make column-set-sequence
    column-set-model: zwei
    space-before: 6pt space-after: 6pt
    (process-children)))
