; props3.scm - the remaining NAMED NODE LISTS and the DECLARATION node classes.
;
; ASCII ONLY and no angle brackets in comments (the .scm is parsed as SGML).
;
; Every value is minted from the reference C++ dazzle. null: / default: are
; both supplied so the golden DISCRIMINATES the four outcomes:
;   a value    - accessOK
;   NULLACC    - accessNull
;   NOTINCL    - accessNotInClass (or an unknown property name)
;   EMPTYNL    - the step BEFORE this one already answered an empty node-list
;
; TWO documented deviations are pinned with OUR value, not the reference's,
; because the reference misbehaves (see props3.expected's
; header):
;   - ad.figform / ad.gifscheme `tokens`: AttributeDefNode::getTokens builds its
;     GroveStrings out of a LOCAL AttributeDefinitionDesc, so the reference
;     prints freed memory (unstable garbage).
;   - `current-group` needs every element type to have an attribute definition
;     list or the reference null-derefs; the fixture document therefore gives
;     each one an ATTLIST, and we stay null-safe.

(declare-flow-object-class fi
  "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")

(define nl "
")
(define (out s) (make fi data: (string-append s nl)))

; the probe: one property of a SINGLETON, with the access results
; discriminated. An EMPTY argument (a failed access one step up, a named-node
; miss) answers EMPTYNL rather than tripping node-property's own type check.
(define (p prop nd)
  (if (node-list-empty? nd)
      'EMPTYNL
      (node-property prop (node-list-first nd) null: 'NULLACC default: 'NOTINCL)))

(define (show v)
  (cond ((symbol? v) (symbol->string v))
        ((string? v) (string-append "\"" v "\""))
        ((char? v) (string-append "#\\" (string v)))
        ((number? v) (number->string v))
        ((null? v) "()")
        ((pair? v) (string-append "(" (join v) ")"))
        ((node-list? v) (string-append "NL:" (number->string (node-list-length v))))
        ((equal? v #t) "#t")
        ((equal? v #f) "#f")
        (else "?")))

(define (join l)
  (if (null? l)
      ""
      (string-append (show (car l))
                     (if (null? (cdr l)) "" " ")
                     (join (cdr l)))))

(define (line tag prop nd)
  (out (string-append tag " " (symbol->string prop) "=" (show (p prop nd)))))

; a NAMED node list: length, named-node-list? and the member names in order
(define (report-nnl tag v)
  (make sequence
    (out (string-append tag " len=" (number->string (node-list-length v))))
    (out (string-append tag " nnl?=" (show (named-node-list? v))))
    (out (string-append tag " names=" (show (named-node-list-names v))))))

; the class names of every member, in order
(define (each-class tag v)
  (if (node-list-empty? v)
      (empty-sosofo)
      (make sequence
        (out (string-append tag " cn=" (show (p 'class-name v))))
        (each-class tag (node-list-rest v)))))

; the intrinsic properties every class carries
(define (report-intrinsic tag nd)
  (make sequence
    (line tag 'class-name nd)
    (line tag 'children-property-name nd)
    (line tag 'data-property-name nd)
    (line tag 'data-sep-property-name nd)
    (line tag 'origin-to-subnode-rel-property-name nd)
    (line tag 'subnode-property-names nd)
    (line tag 'all-property-names nd)
    (out (string-append tag " parent-cn="
                        (show (p 'class-name (parent (node-list-first nd))))))
    (out (string-append tag " origin-cn="
                        (show (p 'class-name (origin (node-list-first nd))))))
    (out (string-append tag " tree-root-cn="
                        (show (p 'class-name (tree-root (node-list-first nd))))))
    (out (string-append tag " grove-root-cn="
                        (show (p 'class-name (p 'grove-root nd)))))
    (out (string-append tag " data=\"" (data nd) "\""))
    (out (string-append tag " kids=" (number->string (node-list-length (children nd)))))
    ; the SIBLING axis: BaseNode::firstSibling is accessNotInClass and none of
    ; the declaration classes overrides it.
    (out (string-append tag " preced=" (number->string (node-list-length (preced nd)))
                        " follow=" (number->string (node-list-length (follow nd)))
                        " first-sib=" (show (first-sibling? nd))
                        " last-sib=" (show (last-sibling? nd))))))

; ---- the grove root -------------------------------------------------------
(define (report-root rt)
  (make sequence
    (line "root" 'sgml-constants rt)
    (line "root" 'application-info rt)
    (line "root" 'governing-doctype rt)
    (line "root" 'doctypes-and-linktypes rt)
    (line "root" 'elements rt)
    (line "root" 'entities rt)
    (line "root" 'defaulted-entities rt)
    (report-nnl "root.dtypes" (p 'doctypes-and-linktypes rt))
    (report-nnl "root.elements" (p 'elements rt))
    (report-nnl "root.entities" (p 'entities rt))
    (report-nnl "root.dflt-ents" (p 'defaulted-entities rt))
    (each-class "root.dtypes" (p 'doctypes-and-linktypes rt))
    (each-class "root.elements" (p 'elements rt))
    (each-class "root.entities" (p 'entities rt))
    (each-class "root.dflt-ents" (p 'defaulted-entities rt))
    (out (string-append "root.named-elem-d1="
                        (show (p 'gi (named-node "d1" (p 'elements rt))))))
    (out (string-append "root.named-elem-f1="
                        (show (p 'gi (named-node "F1" (p 'elements rt))))))
    (out (string-append "root.named-elem-miss="
                        (show (node-list-length (named-node "zz" (p 'elements rt))))))
    (out (string-append "root.named-ent-logo="
                        (show (p 'name (named-node "logo" (p 'entities rt))))))
    (out (string-append "root.named-ent-LOGO="
                        (show (p 'name (named-node "LOGO" (p 'entities rt))))))
    (out (string-append "root.named-dtype="
                        (show (p 'name (named-node "doc" (p 'doctypes-and-linktypes rt))))))
    ; DocEntitiesNamedNodeList::namedNodeU falls back to the grove's DEFAULTED
    ; entity table, so `entities` FINDS a name that is not among its members:
    ; the list itself stops at the general entities (its rest chain loses the
    ; fallback after the first step), which is why the two lengths differ.
    (out (string-append "root.named-ent-missing="
                        (show (p 'name (named-node "missing" (p 'entities rt))))))
    (out (string-append "root.named-ent-pent="
                        (show (p 'name (named-node "pent" (p 'entities rt))))))
    (out (string-append "root.named-gen-missing="
                        (show (p 'name (named-node "missing"
                                         (p 'general-entities (p 'governing-doctype rt)))))))
    (out (string-append "root.norm-Logo=\""
                        (named-node-list-normalize "Logo" (p 'entities rt) 'general)
                        "\""))
    (out (string-append "root.norm-elem-d1=\""
                        (named-node-list-normalize "d1" (p 'elements rt) 'general)
                        "\""))
    (report-intrinsic "root.sgml-constants" (p 'sgml-constants rt))))

; ---- the document-type node ----------------------------------------------
(define (report-doctype dt)
  (make sequence
    (report-intrinsic "dt" dt)
    (line "dt" 'name dt)
    (line "dt" 'governing? dt)
    (line "dt" 'general-entities dt)
    (line "dt" 'parameter-entities dt)
    (line "dt" 'notations dt)
    (line "dt" 'element-types dt)
    (line "dt" 'default-entity dt)
    (report-nnl "dt.gen-ents" (p 'general-entities dt))
    (report-nnl "dt.par-ents" (p 'parameter-entities dt))
    (report-nnl "dt.notations" (p 'notations dt))
    (report-nnl "dt.el-types" (p 'element-types dt))
    (each-class "dt.par-ents" (p 'parameter-entities dt))
    (each-class "dt.notations" (p 'notations dt))
    (each-class "dt.el-types" (p 'element-types dt))
    (out (string-append "dt.named-gen-ent="
                        (show (p 'name (named-node "text-ent" (p 'general-entities dt))))))
    (out (string-append "dt.named-gen-miss="
                        (show (node-list-length (named-node "nope" (p 'general-entities dt))))))
    (out (string-append "dt.named-par-ent="
                        (show (p 'name (named-node "pent" (p 'parameter-entities dt))))))
    (out (string-append "dt.named-notation="
                        (show (p 'name (named-node "gif" (p 'notations dt))))))
    (out (string-append "dt.named-el-type="
                        (show (p 'gi (named-node "p" (p 'element-types dt))))))
    (out (string-append "dt.named-el-type-P="
                        (show (p 'gi (named-node "P" (p 'element-types dt))))))))

; ---- an entity node -------------------------------------------------------
(define (report-entity tag e)
  (make sequence
    (report-intrinsic tag e)
    (line tag 'name e)
    (line tag 'entity-type e)
    (line tag 'text e)
    (line tag 'external-id e)
    (line tag 'attributes e)
    (line tag 'notation-name e)
    (line tag 'notation e)
    (line tag 'defaulted? e)))

; ---- an entity's attribute assignment (an ENTITY-origin assignment, the
;      second origin kind of the attribute-assignment class) ---------------
(define (report-entity-attr tag a)
  (make sequence
    (line tag 'class-name a)
    (line tag 'name a)
    (line tag 'implied? a)
    (line tag 'value a)
    (line tag 'attribute-def a)
    (line tag 'origin-to-subnode-rel-property-name a)
    (out (string-append tag " origin-cn="
                        (show (p 'class-name (origin (node-list-first a))))))
    (out (string-append tag " origin-name="
                        (show (p 'name (origin (node-list-first a))))))
    (out (string-append tag " parent-cn="
                        (show (p 'class-name (parent (node-list-first a))))))
    (out (string-append tag " data=\"" (data a) "\""))
    (out (string-append tag " kids=" (number->string (node-list-length (children a)))))
    (out (string-append tag " preced=" (number->string (node-list-length (preced a)))
                        " follow=" (number->string (node-list-length (follow a)))))))

; ---- an external-id node --------------------------------------------------
(define (report-extid tag x)
  (make sequence
    (report-intrinsic tag x)
    (line tag 'public-id x)
    (line tag 'system-id x)
    (line tag 'generated-system-id x)))

; ---- a notation node ------------------------------------------------------
(define (report-notation tag n)
  (make sequence
    (report-intrinsic tag n)
    (line tag 'name n)
    (line tag 'external-id n)
    (line tag 'attribute-defs n)
    (report-nnl (string-append tag ".attdefs") (p 'attribute-defs n))
    (each-class (string-append tag ".attdefs") (p 'attribute-defs n))))

; ---- an element-type node -------------------------------------------------
(define (report-eltype tag et)
  (make sequence
    (report-intrinsic tag et)
    (line tag 'gi et)
    (line tag 'content-type et)
    (line tag 'exclusions et)
    (line tag 'inclusions et)
    (line tag 'model-group et)
    (line tag 'omit-start-tag? et)
    (line tag 'omit-end-tag? et)
    (line tag 'attribute-defs et)
    (report-nnl (string-append tag ".attdefs") (p 'attribute-defs et))))

; ---- an attribute-def node ------------------------------------------------
(define (report-attdef tag ad)
  (make sequence
    (report-intrinsic tag ad)
    (line tag 'name ad)
    (line tag 'decl-value-type ad)
    (line tag 'default-value-type ad)
    (line tag 'default-value ad)
    (line tag 'current-attribute-index ad)
    (line tag 'current-group ad)))

; ---- a model group / content token ----------------------------------------
(define (report-modelgroup tag mg)
  (make sequence
    (report-intrinsic tag mg)
    (line tag 'connector mg)
    (line tag 'occurence-indicator mg)
    (line tag 'content-tokens mg)
    (each-class (string-append tag ".tokens") (p 'content-tokens mg))))

(define (report-token tag tk)
  (make sequence
    (report-intrinsic tag tk)
    (line tag 'gi tk)
    (line tag 'occurence-indicator tk)))

; ---- the driver -----------------------------------------------------------
(root (process-children))

(element doc
  (let* ((rt (node-property 'grove-root (current-node)))
         (dt (p 'governing-doctype rt))
         (ents (p 'entities rt))
         (ntns (p 'notations dt))
         (ets (p 'element-types dt))
         (docet (named-node "doc" ets))
         (fig (named-node "fig" ets))
         (gifn (named-node "gif" ntns))
         (mg (p 'model-group docet))
         (mgt (p 'content-tokens mg)))
    (make sequence
      (report-root rt)
      (report-doctype dt)
      (report-entity "e.text" (named-node "text-ent" ents))
      (report-entity "e.ext" (named-node "ext-ent" ents))
      (report-entity "e.logo" (named-node "logo" ents))
      (report-entity "e.pi" (named-node "pi-ent" ents))
      (report-entity "e.cd" (named-node "cd-ent" ents))
      (report-entity "e.sd" (named-node "sd-ent" ents))
      (report-entity "e.par" (named-node "pent" (p 'parameter-entities dt)))
      (report-entity "e.dflt" (p 'default-entity dt))
      (report-entity "e.missing" (named-node "missing" (p 'defaulted-entities rt)))
      (report-nnl "e.logo.atts" (p 'attributes (named-node "logo" ents)))
      (report-entity-attr "ea.logo0"
                          (node-list-ref (p 'attributes (named-node "logo" ents)) 0))
      (report-entity-attr "ea.logo1"
                          (node-list-ref (p 'attributes (named-node "logo" ents)) 1))
      (report-extid "x.ext" (p 'external-id (named-node "ext-ent" ents)))
      (report-extid "x.logo" (p 'external-id (named-node "logo" ents)))
      (report-extid "x.gif" (p 'external-id gifn))
      (report-extid "x.tiff" (p 'external-id (named-node "tiff" ntns)))
      (report-extid "x.both" (p 'external-id (named-node "both" ntns)))
      (report-notation "n.gif" gifn)
      (report-notation "n.tiff" (named-node "tiff" ntns))
      (report-eltype "et.doc" docet)
      (report-eltype "et.p" (named-node "p" ets))
      (report-eltype "et.note" (named-node "note" ets))
      (report-eltype "et.hl" (named-node "hl" ets))
      (report-eltype "et.sep" (named-node "sep" ets))
      (report-eltype "et.raw" (named-node "raw" ets))
      (report-eltype "et.anye" (named-node "anye" ets))
      (report-attdef "ad.doc0" (node-list-ref (p 'attribute-defs docet) 0))
      (report-attdef "ad.doc1" (node-list-ref (p 'attribute-defs docet) 1))
      (report-attdef "ad.p1" (node-list-ref (p 'attribute-defs (named-node "p" ets)) 1))
      (report-attdef "ad.figfile" (named-node "file" (p 'attribute-defs fig)))
      (report-attdef "ad.figform" (named-node "form" (p 'attribute-defs fig)))
      (report-attdef "ad.gifres" (named-node "res" (p 'attribute-defs gifn)))
      (report-attdef "ad.gifscheme" (named-node "scheme" (p 'attribute-defs gifn)))
      ; the DEVIATING probe, kept apart: getTokens' dangling GroveStrings.
      (out (string-append "ad.figform tokens=" (show (p 'tokens (named-node "form" (p 'attribute-defs fig))))))
      (out (string-append "ad.gifscheme tokens=" (show (p 'tokens (named-node "scheme" (p 'attribute-defs gifn))))))
      (out (string-append "ad.gifres tokens=" (show (p 'tokens (named-node "res" (p 'attribute-defs gifn))))))
      (report-modelgroup "mg.doc" mg)
      (report-token "tk.doc0" (node-list-ref mgt 0))
      (report-modelgroup "mg.doc1" (node-list-ref mgt 1))
      (report-token "tk.doc2" (node-list-ref mgt 2))
      (report-token "tk.p0" (node-list-ref (p 'content-tokens (p 'model-group (named-node "p" ets))) 0))
      (report-token "tk.p1" (node-list-ref (p 'content-tokens (p 'model-group (named-node "p" ets))) 1))
      ; the element class's own element-type property
      (out (string-append "el.doc.element-type-cn="
                          (show (p 'class-name (p 'element-type (current-node))))))
      (out (string-append "el.doc.element-type-gi="
                          (show (p 'gi (p 'element-type (current-node))))))
      (out (string-append "el.title.element-type-gi="
                          (show (p 'gi (p 'element-type (select-elements (children (current-node)) "title"))))))
      ; IDENTITY: every declaration node is built fresh per access, so equality
      ; is the reference's same2 over the underlying declaration object.
      (out (string-append "id.ent="
                          (show (node-list=? (named-node "logo" ents)
                                             (named-node "logo" (p 'entities rt))))))
      (out (string-append "id.ent-diff="
                          (show (node-list=? (named-node "logo" ents)
                                             (named-node "text-ent" ents)))))
      (out (string-append "id.dtype="
                          (show (node-list=? dt (p 'governing-doctype rt)))))
      (out (string-append "id.eltype="
                          (show (node-list=? docet (named-node "doc" (p 'element-types dt))))))
      (out (string-append "id.attdef="
                          (show (node-list=? (named-node "file" (p 'attribute-defs fig))
                                             (node-list-ref (p 'attribute-defs fig) 1)))))
      (out (string-append "id.attdef-diff="
                          (show (node-list=? (named-node "file" (p 'attribute-defs fig))
                                             (node-list-ref (p 'attribute-defs fig) 0)))))
      (out (string-append "id.extid="
                          (show (node-list=? (p 'external-id gifn)
                                             (p 'external-id (named-node "gif" ntns))))))
      (out (string-append "id.extid-diff="
                          (show (node-list=? (p 'external-id gifn)
                                             (p 'external-id (named-node "tiff" ntns))))))
      (out (string-append "id.modelgroup="
                          (show (node-list=? mg (p 'model-group docet)))))
      (out (string-append "id.token="
                          (show (node-list=? (node-list-ref mgt 0)
                                             (node-list-ref (p 'content-tokens mg) 0)))))
      (out (string-append "id.sgml-constants="
                          (show (node-list=? (p 'sgml-constants rt)
                                             (p 'sgml-constants rt))))))))
