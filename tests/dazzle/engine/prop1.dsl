<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; prop1 - CHARACTER PROPERTIES: the thirteen built-in properties
; (installCharProperties), the declare-char-property / add-char-properties
; declarations, and the char-property primitive that reads them.
;
; *What the golden pins:
;  - the three-step fallback of char-property: the character's OWN value, then
;    the CALLER's optional default, then the property's declared default;
;  - that a declared default must be a CONSTANT - even `(+ 1 2)` is
;    varCharPropertyExprUnsupported, measured, because the reference asks for
;    `constantValue()` after optimizing and a call never folds;
;  - re-declaring in the SAME spec part is `duplicate definition` plus an
;    AUXILIARY line pointing at the first one;
;  - add-char-properties applies EVERY keyword/value pair to EVERY character
;    of the trailing run, and an unknown property name is a diagnostic per
;    character;
;  - the built-in tables themselves: space?, punct?, blank?, record-end?,
;    input-tab?, input-whitespace?, numeric-equiv, script (whose value is the
;    ISO public identifier plus the script name), and the two break
;    priorities;
;  - and that the three properties the reference creates EMPTY (glyph-id and
;    the two drop-*-line-break? flags) answer with their #f default.
;
; *The diagnostics point at the VALUE EXPRESSION, not at the form.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (b v) (if v "#t" "#f"))
(define (p tag v) (out (string-append tag "=" v)))
(define (pn tag v) (out (string-append tag "=" (number->string v))))

(declare-char-property my-prop 1)
; same part, different value -> duplicate + the auxiliary line
(declare-char-property my-prop 2)
; not a constant -> unsupported
(declare-char-property var-prop (+ 1 2))
; a second property, so add-char-properties can set two at once
(declare-char-property other-prop 0)
(add-char-properties my-prop: 9 other-prop: 8 #\a #\b)
(add-char-properties nosuch-prop: 9 #\a)

(element doc (process-children))

(element a (make sequence
  ; --- the three-step fallback -------------------------------------------
  (pn "own"        (char-property 'my-prop #\a))
  (pn "own-b"      (char-property 'my-prop #\b))
  (pn "declared"   (char-property 'my-prop #\z))
  (pn "caller-def" (char-property 'my-prop #\z 77))
  ; a character that HAS a value ignores the caller's default
  (pn "own-wins"   (char-property 'my-prop #\a 77))
  (pn "second"     (char-property 'other-prop #\a))
  (pn "second-def" (char-property 'other-prop #\z))

  ; --- the built-in boolean tables ---------------------------------------
  (p "space-sp"    (b (char-property 'space? #\space)))
  (p "space-x"     (b (char-property 'space? #\x)))
  (p "punct-bang"  (b (char-property 'punct? #\!)))
  (p "punct-x"     (b (char-property 'punct? #\x)))
  (p "blank-nul"   (b (char-property 'blank? #\U-0000)))
  (p "recend-cr"   (b (char-property 'record-end? #\U-000D)))
  (p "tab"         (b (char-property 'input-tab? #\U-0009)))
  (p "inws-sp"     (b (char-property 'input-whitespace? #\space)))

  ; --- numeric-equiv ------------------------------------------------------
  (pn "num-0"      (char-property 'numeric-equiv #\0))
  (pn "num-7"      (char-property 'numeric-equiv #\7))
  (p "num-x"       (b (char-property 'numeric-equiv #\x)))

  ; --- script: the value is the ISO public identifier + the name ---------
  (p "script-a"    (char-property 'script #\a))
  (p "script-alpha" (char-property 'script #\U-03B1))
  (p "script-none" (b (char-property 'script #\U-E000)))

  ; --- the break priorities ----------------------------------------------
  (pn "bbp-sp"     (char-property 'break-before-priority #\space))
  (pn "bap-sp"     (char-property 'break-after-priority #\space))
  (pn "bbp-x"      (char-property 'break-before-priority #\x))

  ; --- the three properties the reference creates EMPTY ------------------
  (p "glyph-id"    (b (char-property 'glyph-id #\a)))
  (p "drop-after"  (b (char-property 'drop-after-line-break? #\a)))
  (p "drop-unless" (b (char-property 'drop-unless-before-line-break? #\a)))
  (p "math-class"  (b (char-property 'math-class #\a)))))

; --- the argument gates of the primitive ---------------------------------
(element b (pn "not-symbol" (char-property "my-prop" #\a)))
(element c (pn "not-char"   (char-property 'my-prop "a")))
(element d (pn "unknown"    (char-property 'no-such-prop #\a)))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
