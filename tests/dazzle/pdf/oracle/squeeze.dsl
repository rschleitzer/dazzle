<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- justified lines squeezed as a word processor's (Dazzle.Pdf 0.11.0):
     justify-squeeze lets a justified line run past the edge by a share of
     its spaces, which are then narrowed; justify-squeeze-word bounds it by
     a share of the word it takes in, justify-squeeze-hyphen at a soft
     hyphen by a share of the syllable before it: the same text without a
     squeeze, with the share alone, with both bounds, with a generous
     share, in a paragraph that is not justified, and with soft hyphens, a bound that
     takes a word or syllable out again -->
(declare-characteristic justify-squeeze
  "UNREGISTERED::Dazzle//Characteristic::justify-squeeze" 0)
(declare-characteristic justify-squeeze-word
  "UNREGISTERED::Dazzle//Characteristic::justify-squeeze-word" 0)
(declare-characteristic justify-squeeze-hyphen
  "UNREGISTERED::Dazzle//Characteristic::justify-squeeze-hyphen" 0)
(define (number name)
  (let ((s (attribute-string name)))
    (if s (string->number s) 0)))
(element doc
  (make simple-page-sequence
    page-width: 120mm page-height: 160mm
    left-margin: 15mm right-margin: 15mm top-margin: 12mm bottom-margin: 12mm
    font-family-name: "Arial" font-size: 10pt line-spacing: 12pt
    (process-children)))
(element p
  (make paragraph space-after: 6pt
    quadding: (if (attribute-string "start") 'start 'justify)
    justify-squeeze: (number "squeeze")
    justify-squeeze-word: (number "word")
    justify-squeeze-hyphen: (number "hyphen")
    end-indent: (if (attribute-string "end") 1.5pt 0pt)
    (process-children)))
