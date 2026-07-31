<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; lang2 - define-language: the diagnostics, the failure modes and the seven
; new syntactic keywords themselves.
;
; What the golden pins:
;  - the only two diagnostics the whole form can produce are
;    syntacticKeywordAsVariable (for a name that IS an expression keyword)
;    and duplicateDefinition (same part, with its "first definition was here"
;    auxiliary line) - EVERY other failure is SILENT, the form simply fails
;    and the top-level loop enters recovery;
;  - the duplicate gate is not doDefine's: the same-part duplicate FAILS the
;    form, so the FIRST language survives unchanged;
;  - the LevelSort accumulator is never reset between levels, so a (forward)
;    level followed by a (backward) one is an error and kills the whole
;    define-language - silently, leaving the name undefined;
;  - an unknown clause key, an unknown collate sub-key, a multi-character
;    collating position that was never declared as an element or symbol, and
;    a toupper pair whose members are not characters all fail the same way;
;  - recovery is per TOKEN, not per form: every later definition is still
;    installed, and the second unknown top level form after a failure is
;    reported only once the parser has resynchronized;
;  - the seven new keys are INERT outside define-language: collate, toupper,
;    tolower, symbol, order, forward and backward all sit above
;    lastSyntacticKey, so they are ordinary variable and procedure names
;    (the same property the five built-in char-property names have).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (b v) (if v "#t" "#f"))
(define (p tag v) (out (string-append tag "=" v)))
(define (pb tag v) (p tag (b v)))

; --- a syntactic keyword as the language name -----------------------------
(define-language make
  (collate (order ((forward)) #\a #\b)))

; --- a duplicate in the SAME part: the FIRST one survives -----------------
(define-language dup (collate (order ((forward)) #\a #\b)))
(define-language dup (collate (order ((forward)) #\b #\a)))

; --- forward then backward: the accumulator is never reset ----------------
(define-language fwbw
  (collate (order ((forward) (backward)) #\a #\b)))

; --- an unknown clause key ------------------------------------------------
(define-language unk1 (bogus 1))

; --- an unknown collate sub-key -------------------------------------------
(define-language unk2 (collate (bogus 1)))

; --- a multi-character collating position that was never declared ---------
(define-language unk3 (collate (order ((forward)) xy)))

; --- a toupper pair that is not a pair of characters ----------------------
(define-language unk4 (toupper (a A)))

; --- the same names as ordinary bindings ----------------------------------
(define collate "collate-value")
(define toupper "toupper-value")
(define (order x) (string-append "order-" x))
(define (forward x) (string-append "forward-" x))
(define backward "backward-value")
(define symbol "symbol-value")
(define tolower "tolower-value")

(declare-default-language dup)

(root
 (make sequence
  ; the first `dup` survived: a before b
  (pb "dup a<b" (string<? "a" "b"))
  (pb "dup b<a" (string<? "b" "a"))
  ; the language named after a syntactic keyword exists all the same
  (pb "language? make" (language? make))
  (pb "language? dup" (language? dup))
  ; the seven keys as plain values
  (p "collate" collate)
  (p "toupper" toupper)
  (p "tolower" tolower)
  (p "symbol" symbol)
  (p "backward" backward)
  (p "order" (order "x"))
  (p "forward" (forward "y"))
 ))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
