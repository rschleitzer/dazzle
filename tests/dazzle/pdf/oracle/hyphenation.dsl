<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- when a line breaks at a soft hyphen that fits (Dazzle.Pdf 0.12.0), as
     a word processor decides: hyphenation-ladder-count of the standard
     bounds the lines in a row that end at a hyphen; hyphenation-zone wants
     more room before the word, from its start or with
     hyphenation-zone-space? from the end of the word before, with
     hyphenation-zone-indent? the start indent counted to it;
     hyphenation-stretch instead in a justified line wants its spaces
     widened by more than a share of a space without the word, and the zone
     does not count there; hyphenation-next-char? wants the character after
     the hyphen to fit as well. The same text without a rule, ragged and
     justified, then each rule beside the paragraph it changes, and
     justify-squeeze-hyphen, which leaves the first syllable of a word to
     the bound of the spaces. Every decision lies more than 0.15pt from its
     limit: the port rounds widths to thousandths of a point -->
(declare-characteristic hyphenation-zone
  "UNREGISTERED::Dazzle//Characteristic::hyphenation-zone" 0pt)
(declare-characteristic hyphenation-zone-space?
  "UNREGISTERED::Dazzle//Characteristic::hyphenation-zone-space?" #f)
(declare-characteristic hyphenation-zone-indent?
  "UNREGISTERED::Dazzle//Characteristic::hyphenation-zone-indent?" #f)
(declare-characteristic hyphenation-stretch
  "UNREGISTERED::Dazzle//Characteristic::hyphenation-stretch" 0)
(declare-characteristic hyphenation-next-char?
  "UNREGISTERED::Dazzle//Characteristic::hyphenation-next-char?" #f)
(declare-characteristic justify-squeeze
  "UNREGISTERED::Dazzle//Characteristic::justify-squeeze" 0)
(declare-characteristic justify-squeeze-hyphen
  "UNREGISTERED::Dazzle//Characteristic::justify-squeeze-hyphen" 0)
(define (number name default)
  (let ((s (attribute-string name)))
    (if s (string->number s) default)))
(define (flag name)
  (if (attribute-string name) #t #f))
(element doc
  (make simple-page-sequence
    page-width: 120mm page-height: 250mm
    left-margin: 15mm right-margin: 15mm top-margin: 12mm bottom-margin: 12mm
    font-family-name: "Arial" font-size: 10pt line-spacing: 12pt
    (process-children)))
(element p
  (make paragraph space-after: 6pt
    quadding: (if (flag "start") 'start 'justify)
    start-indent: (* (number "indent" 0) 1pt)
    hyphenation-ladder-count: (number "ladder" #f)
    hyphenation-zone: (* (number "zone" 0) 1pt)
    hyphenation-zone-space?: (flag "zspace")
    hyphenation-zone-indent?: (flag "zindent")
    hyphenation-stretch: (number "stretch" 0)
    hyphenation-next-char?: (flag "next")
    justify-squeeze: (number "squeeze" 0)
    justify-squeeze-hyphen: (number "hyphen" 0)
    (process-children)))
