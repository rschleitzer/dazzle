<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
; A recursion that is not a tail call and answers a constant: each frame's
; result lies outside its span, so the frame mark rewinds it -- and forty
; levels grow the control stack of the VM that evaluates the characteristic
; while such frames are running.
(define (deep n)
  (if (= n 0)
      #t
      (and (deep (- n 1)) #t)))
(define (wide n)
  (if (= n 0)
      #t
      (and (deep 40) (wide (- n 1)) #t)))
(element doc (make simple-page-sequence (process-children)))
(element p
  (make paragraph
    quadding: (if (wide 20) 'start 'end)
    (process-children)))
