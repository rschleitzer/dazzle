<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; conv1 - Interpreter::convertFromString (Interpreter.cxx:1095), the `-2`
; STRING LENIENCY of the characteristic converters. Under -2 every value
; goes through convertFromString before its converter, so a STRING may
; stand in for the number, symbol or boolean the converter wants. The
; matrix runs over the CONVERSION KINDS, not over the flow object classes:
; the coercion is a property of the converter, and each converter names its
; own hints (a union over all three would reinterpret a genuine string).
;
; Run twice: conv1 (-2) is this matrix, conv1b is the SAME file WITHOUT the
; flag, where every one of these values is an `invalid value`.

(element a
  (make sequence
    ; --- boolean (convertBooleanC, convertAllowBoolean) -------------------
    ; the four spellings the reference accepts, and nothing else
    (make paragraph hyphenate?: "yes" kern?: "true" ligature?: "no"
                    score-spaces?: "false"
      (literal "bool"))
    ; NOT accepted: case is not folded (the reference's own FIXME), a number
    ; is not a boolean (no convertAllowNumber here), and neither is a symbol
    (make paragraph hyphenate?: "YES" kern?: "1" ligature?: "yes "
      (literal "boolbad"))))

(element b
  (make sequence
    ; --- integer (convertIntegerC, convertAllowNumber) --------------------
    ; convertNumber's whole syntax reaches the characteristic: a plain
    ; integer, a signed one and the radix prefixes
    (make paragraph line-number-side: 'start
                    lines: 'wrap
      (make line-field field-width: "72"))
    (make line-field field-width: "#x48")
    (make line-field field-width: "+9")
    (make line-field field-width: "-4")
    ; NOT an exact integer: a real, a length (dimension 1) and a non-number
    (make line-field field-width: "7.5")
    (make line-field field-width: "3pt")
    (make line-field field-width: "seven")))

(element c
  (make sequence
    ; --- length / length-spec (convertLengthC, convertLengthSpecC) --------
    (make paragraph space-before: "12pt" start-indent: "1in"
                    end-indent: "2.5cm" first-line-start-indent: "-6pt"
      (literal "len"))
    ; a DIMENSIONLESS number is no length, and display-size arithmetic
    ; cannot be spelled as a string
    (make paragraph space-before: "12" start-indent: "1/2"
      (literal "lenbad"))
    ; the display NIC of a non-inherited characteristic takes the same route
    (make display-group space-before: "6pt" space-after: "8pt"
      (literal "nic"))))

(element d
  (make sequence
    ; --- enum (convertEnumC, convertAllowSymbol|convertAllowBoolean) ------
    ; a string naming a symbol WITH a c-value converts; #t/#f spellings do
    ; too, through the boolean half
    (make paragraph quadding: "center" lines: "asis"
                    font-posture: "italic" writing-mode: "left-to-right"
      (literal "enum"))
    ; a name that is no symbol of the table at all, and one that is a symbol
    ; but has no c-value (`foo` is used as a symbol below)
    (make paragraph quadding: "middle" lines: (quote wrap)
      (literal "enumsym"))
    (make paragraph quadding: "foo"
      (literal "enumnoc"))
    ; the ALLOWED-SET overload: a converted symbol still has to be in the set
    (make rule orientation: "escapement" break-before-priority: "3")
    (make rule orientation: "vertical")))

(element e
  (make sequence
    ; --- real (convertRealC) ---------------------------------------------
    (make character char: #\A stretch-factor: "2.5")
    (make character char: #\B stretch-factor: "3")
    (make character char: #\C stretch-factor: "big")
    ; --- optional forms: the leniency runs BEFORE the #f test -------------
    ; convertOptPositiveIntegerC ("no" -> #f -> 0, a positive integer, and
    ; the two rejections: zero and a non-number)
    (make paragraph expand-tabs?: "no" (literal "opi-no"))
    (make paragraph expand-tabs?: "4" (literal "opi-4"))
    (make paragraph expand-tabs?: "0" (literal "opi-0"))
    ; convertOptLengthSpecC (min-leading), and the inline-space form
    (make paragraph min-leading: "no" (literal "ols-no"))
    (make paragraph min-leading: "2pt" (literal "ols-2pt"))
    (make paragraph inline-space-space: "no" (literal "ois-no"))
    (make paragraph inline-space-space: "3pt" (literal "ois-3pt"))))

(element f
  (make sequence
    ; --- what must NOT be coerced ----------------------------------------
    ; a STRING characteristic keeps its string: no hint fits it, so "5" is
    ; the text "5" and not the number 5
    (make paragraph (make formatting-instruction data: "5"))
    ; a public-id characteristic likewise (convertPublicIdC is not gated)
    (make paragraph font-name: "12" (literal "pubid"))
    ; a char characteristic is a one-character string EVEN without -2
    ; (convertCharC has always taken one)
    (make character char: "Z")
    ; the RAW convertLengthSpec of the display-space PRIMITIVE is NOT gated:
    ; its argument is no characteristic, so a string stays "not a length or
    ; length-spec" even under -2. *The error value goes to an IGNORED
    ; characteristic on purpose - fed to a real one, the reference prints an
    ; unspecified space out of the uninitialized DisplaySpace it built before
    ; the argError, a quirk of its error path unrelated to this conversion.
    (make paragraph line-dash: (display-space "4pt") (literal "rawls"))
    ; and an unknown UNIT still messages, because the number arm resolves
    ; quantities right here
    (make paragraph space-before: "3zz" (literal "unit"))))

(define foo 'foo)
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
