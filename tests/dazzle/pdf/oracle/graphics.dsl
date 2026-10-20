<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- graphics: as they are, scaled by one factor and by two, 'max-uniform
     (the initial value) within max-width, max-height or both, 'max each
     direction on its own, a max-width beyond the area, and a graphic in a
     line -->
(define (points name)
  (let ((s (attribute-string name)))
    (if s (* (string->number s) 1pt) #f)))
(define (scale-of)
  (let ((s (attribute-string "scale")))
    (cond ((not s) 'max-uniform)
          ((equal? s "max") 'max)
          ((equal? s "max-uniform") 'max-uniform)
          ((equal? s "2 0.5") '(2 0.5))
          (else (string->number s)))))
(element doc
  (make simple-page-sequence
    page-width: 150mm page-height: 200mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 10pt line-spacing: 12pt
    (process-children)))
(element p
  (make paragraph space-after: 3pt (process-children)))
(define (graphic display mw mh)
  (cond ((and mw mh)
         (make external-graphic entity-system-id: "figure.png" display?: display
           space-after: (if display 4pt 0pt) scale: (scale-of) max-width: mw max-height: mh))
        (mw
         (make external-graphic entity-system-id: "figure.png" display?: display
           space-after: (if display 4pt 0pt) scale: (scale-of) max-width: mw))
        (mh
         (make external-graphic entity-system-id: "figure.png" display?: display
           space-after: (if display 4pt 0pt) scale: (scale-of) max-height: mh))
        (else
         (make external-graphic entity-system-id: "figure.png" display?: display
           space-after: (if display 4pt 0pt) scale: (scale-of)))))
(element fig
  (graphic (equal? (gi (parent (current-node))) "doc") (points "mw") (points "mh")))
