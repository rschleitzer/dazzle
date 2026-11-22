<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<style-sheet>
<style-specification>
<style-specification-body>
;; Formulas made of the math flow objects: atoms spaced by their math class,
;; a binary minus and a sign, a script with a superscript and a subscript, a
;; fraction and a fence -- in a line of text in the text style, alone in
;; their paragraphs in the display style. Set by the constants of the MATH
;; table of the font (mathfonts/tiny-ps.otf: the k-th value k * 10).
(define (ch c cls) (make character char: c math-class: cls))
(define (var c) (make sequence font-posture: 'italic (ch c 'ordinary)))
(define (formula name)
  (cond
    ((equal? name "sum")
     (make math-sequence (var #\a) (ch #\+ 'binary) (var #\b) (ch #\= 'relation) (var #\c)))
    ((equal? name "script")
     (make math-sequence
       (make script
         (var #\x)
         (make math-sequence label: 'post-sup (ch #\2 'ordinary))
         (make math-sequence label: 'post-sub (var #\i)))))
    ((equal? name "fraction")
     (make math-sequence
       (var #\y) (ch #\= 'relation)
       (make fraction
         (make math-sequence label: 'numerator (var #\a) (ch #\+ 'binary) (var #\b))
         (make math-sequence label: 'denominator (var #\c)))))
    (else
     (make math-sequence
       (ch #\U-2212 'binary) (ch #\1 'ordinary) (ch #\U-2212 'binary)
       (make fence
         (make sequence label: 'open (ch #\( 'opening))
         (make sequence label: 'close (ch #\) 'closing))
         (var #\a) (ch #\U-2212 'binary) (var #\b))))))
(element doc
  (make simple-page-sequence
    page-width: 120mm page-height: 80mm
    left-margin: 10mm right-margin: 10mm top-margin: 10mm bottom-margin: 10mm
    font-family-name: "Tiny PS" font-size: 12pt line-spacing: 16pt
    (process-children)))
(element p (make paragraph space-before: 4mm quadding: 'center (process-children)))
(element m (formula (attribute-string "n")))
</style-specification-body>
</style-specification>
</style-sheet>
