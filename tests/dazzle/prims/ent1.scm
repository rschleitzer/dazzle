; ent1.scm - the ENTITY and NOTATION lookup primitives (primitive.h:134-145):
; entity-text, entity-type, entity-attribute-string, entity-name-normalize
; and the three notation-*-id, over the four that were already ported
; (entity-system-id, entity-public-id, entity-generated-system-id,
; entity-notation) so the whole family is pinned in one place.
;
; The document (a copy of the grove suite's decls.sgml) declares one entity of
; EVERY type - internal text, external text, NDATA, PI, CDATA, SDATA, a
; parameter entity and a #DEFAULT entity - and three notations covering PUBLIC
; only, SYSTEM only and both, one of them with a #NOTATION attribute list.
;
; ★What the golden pins beyond the values: these primitives do not
; distinguish "no such entity" from "that entity has no such property". Every
; link of the reference's chained accessOK test collapses to the SAME #f, so
; an unknown name and an external entity asked for its text are
; indistinguishable. Only entity-name-normalize breaks the pattern: it
; ignores every access result and always answers a string.
;
; ASCII ONLY, and MARKUP-FREE (see num1.scm).

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))
(define (show v)
  (cond ((string? v) (string-append "s:" v))
        ((symbol? v) (string-append "y:" (symbol->string v)))
        ((boolean? v) (if v "#t" "#f"))
        (else "?")))
(define (p tag v) (out (string-append tag "=" (show v))))

(element doc (make sequence

  ; --- entity-type over every declared type ------------------------------
  (p "type-text"   (entity-type "text-ent"))
  (p "type-ext"    (entity-type "ext-ent"))
  (p "type-ndata"  (entity-type "logo"))
  (p "type-pi"     (entity-type "pi-ent"))
  (p "type-cdata"  (entity-type "cd-ent"))
  (p "type-sdata"  (entity-type "sd-ent"))
  (p "type-param"  (entity-type "pent"))
  (p "type-miss"   (entity-type "nosuch"))

  ; --- entity-text: internal arms only -----------------------------------
  (p "text-text"   (entity-text "text-ent"))
  (p "text-pi"     (entity-text "pi-ent"))
  (p "text-cdata"  (entity-text "cd-ent"))
  (p "text-sdata"  (entity-text "sd-ent"))
  (p "text-param"  (entity-text "pent"))
  ; an EXTERNAL entity has no text - same #f as an unknown name
  (p "text-ext"    (entity-text "ext-ent"))
  (p "text-ndata"  (entity-text "logo"))
  (p "text-miss"   (entity-text "nosuch"))

  ; --- the already-ported external-id trio, for contrast -----------------
  (p "sysid-ext"   (entity-system-id "ext-ent"))
  (p "sysid-int"   (entity-system-id "text-ent"))
  (p "pubid-ext"   (entity-public-id "ext-ent"))
  (p "notation"    (entity-notation "logo"))
  (p "notation-i"  (entity-notation "text-ent"))

  ; --- entity-attribute-string: the NDATA entity's data attributes -------
  (p "eas-res"     (entity-attribute-string "logo" "res"))
  (p "eas-scheme"  (entity-attribute-string "logo" "scheme"))
  ; declared but IMPLIED with no value
  (p "eas-implied" (entity-attribute-string "logo" "res"))
  (p "eas-noattr"  (entity-attribute-string "logo" "nosuch"))
  ; an entity with no data attributes at all
  (p "eas-nodata"  (entity-attribute-string "text-ent" "res"))
  (p "eas-miss"    (entity-attribute-string "nosuch" "res"))

  ; --- entity-name-normalize: never #f -----------------------------------
  (p "enn-lower"   (entity-name-normalize "logo"))
  (p "enn-upper"   (entity-name-normalize "LOGO"))
  (p "enn-mixed"   (entity-name-normalize "LoGo"))
  (p "enn-miss"    (entity-name-normalize "no-such-entity-at-all"))
  (p "enn-empty"   (entity-name-normalize ""))

  ; --- the three notation ids over the three declaration shapes ----------
  (p "nsys-gif"    (notation-system-id "gif"))
  (p "nsys-tiff"   (notation-system-id "tiff"))
  (p "nsys-both"   (notation-system-id "both"))
  (p "npub-gif"    (notation-public-id "gif"))
  (p "npub-tiff"   (notation-public-id "tiff"))
  (p "npub-both"   (notation-public-id "both"))
  (p "ngen-gif"    (notation-generated-system-id "gif"))
  (p "ngen-tiff"   (notation-generated-system-id "tiff"))
  (p "ngen-both"   (notation-generated-system-id "both"))
  (p "nsys-miss"   (notation-system-id "nosuch"))
  (p "npub-miss"   (notation-public-id "nosuch"))
  (p "ngen-miss"   (notation-generated-system-id "nosuch"))

  ; --- the optional NODE argument: any singleton reaches the same grove --
  (p "node-arg"    (entity-type "logo" (current-node)))
  (p "node-arg2"   (notation-public-id "gif" (current-node)))
))
(default (empty-sosofo))
