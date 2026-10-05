<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; ccp1 - declare-char-characteristic+property: the one declaration that
; installs TWO things at once, a CHAR NIC (a non-inherited characteristic of
; the `character` flow object, registered on the Identifier itself by
; Interpreter::installExtensionCharNIC) and a character property of the same
; name with the same default (the very same addCharProperty that
; declare-char-property calls).
;
; What the golden pins:
;  - the property half is a real char property: add-char-properties sets it
;    per character and char-property reads it, default and all;
;  - the default must be a CONSTANT, exactly as in declare-char-property -
;    a non-constant is varCharPropertyExprUnsupported and the property is
;    then never created at all, so reading it is `unknown character
;    property`;
;  - the duplicate gate is the MIRROR IMAGE of declare-characteristic's:
;    a name carrying a characteristic is refused with NO part comparison
;    (a built-in one too), a name already registered as a char NIC only
;    within the same part;
;  - and the refusal happens BEFORE the property half, so the first
;    declaration's default survives;
;  - the reverse direction: a char NIC makes a later declare-characteristic
;    of that name `duplicate characteristic` - the gate this port did not
;    model at all before;
;  - the diagnostics point at the FORM, not at the value expression (the
;    reference takes setNextLocation(loc) at entry) - the opposite of
;    declare-char-property;
;  - and that the five built-in char-property names the reference also keys
;    (space? punct? record-end? input-tab? input-whitespace?) are INERT:
;    they sit above lastSyntacticKey, so they are still ordinary procedure
;    names.
;
; The public identifier is parsed and then DROPPED - a char NIC never
; reaches a backend.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (b v) (if v "#t" "#f"))
(define (p tag v) (out (string-append tag "=" v)))
(define (pn tag v) (out (string-append tag "=" (number->string v))))

; --- the plain declaration ------------------------------------------------
(declare-char-characteristic+property my-cnic
  "UNREGISTERED::Example//Characteristic::my-cnic" 5)
; ... and the property half behaves like any other char property
(add-char-properties my-cnic: 7 #\a)

; --- the default must be a constant --------------------------------------
(declare-char-characteristic+property var-cnic
  "UNREGISTERED::Example//Characteristic::var-cnic" (+ 1 2))

; --- duplicate in the SAME part: refused, and the first default survives ---
(declare-char-characteristic+property my-cnic
  "UNREGISTERED::Example//Characteristic::my-cnic-again" 6)

; --- a BUILT-IN characteristic name: refused with no part comparison ------
(declare-char-characteristic+property font-size
  "UNREGISTERED::Example//Characteristic::font-size" 1)

; --- a name this part declared with declare-characteristic: also refused ---
(declare-characteristic ext-c
  "UNREGISTERED::Example//Characteristic::ext-c" 0)
(declare-char-characteristic+property ext-c
  "UNREGISTERED::Example//Characteristic::ext-c-again" 3)

; --- the reverse direction: a char NIC refuses declare-characteristic -----
(declare-characteristic my-cnic
  "UNREGISTERED::Example//Characteristic::my-cnic-as-ic" 0)

; --- the keyed property names are still ordinary names --------------------
(define (space? c) (char-property 'space? c))
(define (punct? c) (char-property 'punct? c))

(element doc (process-children))

(element a (make sequence
  (pn "own"      (char-property 'my-cnic #\a))
  (pn "declared" (char-property 'my-cnic #\z))
  (pn "caller"   (char-property 'my-cnic #\z 77))
  (pn "own-wins" (char-property 'my-cnic #\a 77))))

(element b (pn "var-cnic" (char-property 'var-cnic #\a)))

(element c (make sequence
  (p "space-sp" (b (space? #\space)))
  (p "space-x"  (b (space? #\x)))
  (p "punct-!"  (b (punct? #\!)))))

(element d (pn "nopubid" (char-property 'nopubid-cnic #\a)))

; --- LAST, because #f for the public identifier is dsssl2-only ------------
(declare-char-characteristic+property nopubid-cnic #f 42)
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
