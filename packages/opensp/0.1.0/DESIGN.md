# opensp — design notes

Per-stage design notes for the OpenSP port (ROADMAP-dazzle.md Part I). Each
stage records its RBMM residency mapping and any multiple-inheritance
resolution before the code lands.

## Stage 1 — foundation layer

### Memory: one region per parse run

OpenSP's C++ manages lifetime with an intrusive ref-counting graph
(`Ptr<T>`/`ConstPtr<T>`, `Owner<T>`), because entities are shared between the
DTD and the document instance and freed at different times. The port collapses
all of that:

- **A parse run is one arena region.** Everything a run allocates — StringC
  buffers, messages, locations, origins, input sources, the entity graph —
  lives until the run's region dies. No counts, no frees during the run.
- `Owner<T>` (sole ownership) → **a plain field** holding the value/pointer.
- `Ptr<T>` / `ConstPtr<T>` (shared, counted) → **a plain borrowed pointer**;
  sharing is free because nothing is reclaimed early.
- `Vector`/`HashTable`/`IList`/`ISet` → the Scaly containers per the standing
  rules (List for unknown counts, Vector to freeze, Array for growth). Intrusive
  lists are ported faithfully only where an algorithm depends on the threading.

The residency consequence for every foundation value that owns a buffer or
sub-objects: it must be **page-resident** so `Page.get(this)` yields the run's
region. Construction happens on the destination page chosen at the call site
(local / `#` caller page / `^this` owner page), exactly as `scaly.containers`
does.

### Char = u32, StringC over Char

- `Char` is a **32-bit codepoint** (`u32`) end-to-end. External bytes are
  decoded to Char by CodingSystems at the I/O boundary and never re-encoded
  inside the parser. This mirrors the C++/C# choice and dodges a whole
  multibyte bug class.
- `Xchar` is **`i32`** (C# `Int32`): holds any `Char` value plus **`-1` as the
  end-of-entity / EOF sentinel** (`InputSource.eE = -1`). `Char` fits in i32's
  positive range (charMax = 0x10FFFF), so the sentinel is unambiguous.
- `Token` is **`u32`**: not an enum but named constants (`tokenUnrecognized=0`,
  `tokenEe=1` end-of-entity, S/RE/RS/data 2–12, delimiter tokens 13–60,
  `tokenFirstShortref=61`). Distinct from the Xchar EOF sentinel.
- Related codepoint aliases (`UnivChar`/`SyntaxChar`/`WideChar` = u32;
  `Number`/`Offset`/`Index` = u32) are all plain `u32`/`size_t` in the port.
- **`StringC`** = a small value `{ data: pointer[u32], size: size_t }` whose
  Char buffer is region-allocated on the value's own page (`Page.get(this)`),
  mirroring `scaly.containers.String` residency but over u32 elements. Copies
  are shallow — sound inside one region. `CHAR_BYTES = 4` is the element size
  for allocation. The byte⟷Char boundary lives in CodingSystems, never in
  StringC. (Landed: `opensp/StringC.scaly`, foundation self-test green.)

### Multiple-inheritance sites

OpenSP mixes classes freely (e.g. an object that is both an `EventHandler` and
a `Messenger`). Scaly has no MI, so each site resolves case-by-case to either a
trait/`implement` or composition, recorded here.

Only **two** foundation MI sites exist (verified against upstream `*.h`); the
C# port already collapsed both, and the port follows its lead:

1. **`CodingSystem`** — C++ `: public InputCodingSystem, public
   OutputCodingSystem`. Resolution: **compose the output half.** `CodingSystem`
   carries the input interface (`makeDecoder`, `convertIn`); the encoder side
   (`makeEncoder`, `convertOut`, `fixedBytesPerChar`) is provided as ordinary
   methods on the same concept (the C# port duplicated them inline — we keep
   them as members, no separate interface). Round-trips only need decode+encode
   on one concept, so a single `CodingSystem` concept with both is simplest.
2. **`MessageReporter`** — C++ `: public MessageFormatter, public Messenger`.
   Resolution: **`MessageReporter` IS-A `Messenger`; it HAS-A formatting
   behavior** reimplemented as its own methods (getMessageText / formatMessage
   / formatFragment / formatOpenElements), exactly as the C# port did.
   `MessageFormatter` stays a separate reusable concept for the abstract
   `%1..%9` substitution machinery.

Single-inheritance base facts to carry over: `Origin`/`InputCodingSystemKit`
derive from a ref-counted `Resource` (→ drop the counting, plain field/pointer
in the arena); `InputSource : Link` (intrusive list node — ported faithfully
if the algorithm threads sources); `MessageArg`/`MessageBuilder` are interfaces
(→ Scaly trait or a small union/dispatch). **Pointer-arithmetic note:** the C#
port fakes C++ `const Char*` cursors as array-ref + `nuint` index pairs; Scaly
has real pointers, so `InputSource`/`StringC` restore the single-cursor form.
`ProloguesOrigin` does NOT exist (don't port it).

### Type inventory (Stage 1) and port order

Port order (dependency-first), with the C# source sizes as a size gauge:

1. **types** — `Char`/`Xchar`/`Token` + `Tokens` constants + charset limits
   (`GlobalUsings.cs` 32, `Constant.cs` 13, `Token.cs` 74). Trivial.
2. **StringC** — grow to `String<Char>` shape: `{data, size, alloc}`, append
   char / append StringC / indexer / `==` / substr / hash (`StringC.cs` 150,
   `StringOf.cs` 418). Started; landed minimal, extend with append+capacity.
3. **CodingSystem layer** — `Decoder`/`Encoder` abstract, `Identity` (74),
   `UTF8` (333), `XML` autodetect (472), plus the `CodingSystemKit` that wires
   exactly those three (`CodingSystem.cs` 210, `CodingSystemKit.cs` 127).
   Exotic ones (Big5/EUCJP/SJIS/Fixed2/Fixed4/UTF16/Unicode/Win32/Translate) —
   **omitted; a name lookup for them falls back LOUD** (kit resolves only
   Identity/UTF-8/XML, mirroring `CodingSystemKitImpl`). → round-trip harness.
4. **Message layer** — `MessageFragment`/`MessageType`(+arity `0..6`,`L`),
   `MessageArg`(interface)+`String`/`Number`/`Ordinal`/`Token`/`Location` args,
   `Message`, `MessageBuilder`(interface), `MessageFormatter` (`%1..%9`),
   `Messenger`+`MessageReporter` (`Message.cs` 495, `MessageArg.cs` 270,
   `MessageFormatter.cs` 231, `MessageReporter.cs` 448). → formatting harness.
5. **Location/Origin/InputSource** — `Location` (origin,index), `Origin`
   hierarchy (Proxy/Bracket/Replacement/NumericCharRef/InputSourceOrigin[Impl]/
   EntityOrigin[Impl]), `ExternalInfo`/`StorageObjectPosition`, `InputSource`
   (+`InternalInputSource`) with the array→pointer cursor simplification
   (`Location.cs` 458, `InputSource.cs` 443). → nested-source location harness.

`ExternalInputSource` + the full `ExtendEntityManager` storage layer belong to
Stage 2 (entity layer); Stage 1 ports `InternalInputSource` (in-memory) only,
enough for location tracking through nested (pushed) sources.

### Landed (Stage 1)

All four exit criteria green through the JIT (`tests/opensp/run.sh` → `PASS`;
`opensp.test()` chains the module self-tests):

- **`StringC.scaly`** — `{data, size}` Char value, page-resident buffer;
  construct-from-buffer / ASCII-widen ctor / get / equals.
- **`CodingSystem.scaly`** — Identity + UTF-8 + XML-autodetect as a closed
  union/choose; stateless whole-buffer decode/encode **round-trips** (incl.
  multi-codepoint UTF-8 and UTF-8-BOM strip). Exotic systems LOUD (exit 120);
  UTF-16 BOM LOUD (exit 121). OutputByteStream sink deferred to Stage 2.
- **`Message.scaly`** — `Severity`, `MessageFragment`, `MessageType.is_error`,
  `MessageArg` union (Str/Num/Ord), `MessageFormatter.format` with **`%1..%9`
  substitution** (string quoting honouring noquote, decimal numbers, ordinal
  suffixes). MessageBuilder/OutputCharStream sink deferred (writes a Char
  buffer). Token/Location/Other args land with their producers.
- **`Location.scaly`** — `Location` (origin,index), `Origin` (models
  InputSourceOrigin, `parent()`→ref location), in-memory `InputSource`;
  **location tracking through nested pushed sources** via the parent chain.
  Streaming `fill()`/mutable cursor + the rest of the Origin hierarchy: Stage 2+.

Deferred within Stage 1 by scope (not blockers): the full `Tokens` constant
table (lands with the lexer, Stage 3), OutputByteStream/OutputCharStream sinks
(Stage 2 IO), streaming decoder state (Stage 2). opensp is a standalone package
outside the seed/compiler build, so these additions are emission-neutral
(`tools/cycle.sh` IDENTICAL).

## Stage 2 — entity layer

Turns an external identifier (PUBLIC/SYSTEM) into an `InputSource`, via the
catalog → storage → decoder → source chain, and stacks entities as pushed
input sources.

### Memory & I/O boundary

- Same one-region-per-run rule: storage objects, the resolved entity graph
  (shared between DTD and instance), and catalog tables all live to run end.
  `Owner<StorageObject>`/`Owner<Entity>` → plain fields; the entity graph's
  cross-references are borrowed pointers.
- **File I/O boundary = `scaly.io`.** `FileStorageManager` reads a file with
  `File.read_to_string` (returns a byte `String`); its bytes feed a
  `CodingSystem` decoder → Char buffer → `StringC` → `InputSource`. Path
  resolution uses `Path.join`/`get_directory_name`. `LiteralStorageManager`
  wraps an in-memory byte string with no I/O.

### SGML Open catalog format (what the parser must accept)

Line/token oriented; `--…--` comments; entries are a keyword + optional quoted
id(s) + a target file, resolved relative to the catalog's own directory:
`OVERRIDE YES|NO`, `PUBLIC "<pubid>" <file>`, `SYSTEM "<sysid>" <file>`,
`DOCTYPE <name> <file>`, `ENTITY [%]<name> <file>`, `SGMLDECL <file>`,
`CATALOG <file>` (chain to another catalog). Catalog search path comes from
`SGML_CATALOG_FILES` (env) / `-c`. Most corpus documents use `PUBLIC "…//EN"
"sysfallback.dtd"` and resolve by the SYSTEM fallback relative to the document
— catalog lookup is the override path.

### Type inventory & MI (Stage 2)

**No true MI anywhere in this layer** (verified vs upstream headers); the C#
`IDisposable`/`IMessenger` mix-ins are interfaces, irrelevant here. The C++
hierarchies port to Scaly unions (StorageManager, Entity) + concepts.

Stage 2 ports the **entity machinery**, unit-tested on synthetic in-memory
inputs. The C# layer is huge (ExtendEntityManager 1504, SOEntityCatalog 1185,
ExternalId 620, PosixStorage 582 LOC); we take the algorithm-faithful core and
defer the breadth (see "deferred" below). Corpus-wide entity-graph resolution
(the roadmap exit) genuinely needs the prolog/DTD parser to drive it, so it
couples with Stage 3; Stage 2's gate is the machinery + resolve-and-dump on
synthetic catalogs/entities.

- **Storage** — `StorageManager`/`StorageObject` (abstract factory + byte
  reader) port to a `Storage` union: `Literal(bytes: StringC-of-u8-ish)` (no
  I/O, from `LiteralStorage.cs`) and `File(base_dir)` (from `PosixStorage.cs`,
  reads via `scaly.io.File.read_to_string`). `read(spec_id) → byte String`;
  `resolve_relative(base, spec)` via `Path`. Rewind/block-size/search-dirs and
  the Fd/URL/WinInet/Stdio managers are deferred.
- **ExternalId** (`ExternalId.cs`) — `{ has_public, public_id, has_system,
  system_id }` + accessors. **IDs/paths are byte `String`, not StringC**: public
  ids, system ids and file paths are ASCII/Latin-1 identifiers at the I/O
  boundary, so they live on the byte side; StringC (u32) is reserved for Char
  CONTENT (entity text → InputSource). This refines the earlier StringC note.
  Formal-public-id PARSING (`PublicId` FPI/URN fields, TextClass) is deferred —
  Stage 2 holds the public-id string; classification lands on demand.
- **EntityCatalog** (`EntityCatalog.cs` + `SOEntityCatalog.cs`/`CatalogParser`)
  — parse an SGML Open catalog (keyword tokenizer over `--…--` comments):
  `PUBLIC`/`SYSTEM`/`DOCTYPE`/`ENTITY`/`SGMLDECL`/`OVERRIDE`/`CATALOG`. Tables:
  public→entry, system→entry, and per-`DeclType` name maps (doctype/entity/…).
  `lookup_public`/`lookup_system`/`lookup(EntityDecl)` → resolved system id,
  honouring OVERRIDE, resolved relative to the catalog's own directory. Nested
  `CATALOG` chaining supported; DELEGATE/DTDDECL/BASE deferred.
- **EntityManager** (`EntityManager.cs`/`ExtendEntityManager`) — `open(sysid,
  storage, origin) → InputSource`: resolve → `Storage.read` bytes → CodingSystem
  decode → StringC → `InputSource`. `ParsedSystemId`'s `<osfile>` bracket-FSI
  syntax + record normalization deferred (default OSFILE, whole-buffer decode).
- **Entity** (`EntityDecl.cs`/`Entity.cs`) — `Entity` union:
  `Internal(name, text: StringC, data_type)` and `ExternalText(name,
  external_id)`; `DeclType`/`DataType` enums. **Stacking** = the `normalReference`
  path: internal → push an `InputSource` over `text`; external → catalog
  `lookup` + `EntityManager.open`, push the source. The pushed source's origin
  carries the reference `Location` (nested tracking from Stage 1). Data
  entities (cdata/sdata/ndata/subdoc → events) and the recursion guard are
  deferred to the parser stages.

Port order (map's, condensed): Storage → ExternalId → EntityCatalog →
EntityManager.open → Entity + stacking. File-I/O touches only `Storage.File`
(→ `scaly.io.File`); everything above reaches bytes only through `Storage.read`.

## Stage 3 — declarations: SGML decl, prolog, DTD (in progress)

The summit before instance parsing: parse the SGML/implied-XML declaration, the
prolog (DOCTYPE + internal/external subset), and the markup declarations
(ELEMENT/ATTLIST/ENTITY/NOTATION), compiling content models to a DFA and
building the `Dtd`.

### Scope (this is a multi-increment stage)

Far larger than Stages 1–2 (the C++ parser family is thousands of LOC). Ported
as separable increments, each JIT-tested:
1. **`Tokens` table** (`Token.cs`) — the 61 lexer tokens + `tokenFirstShortref`
   (read; ready to land).
2. **`Sd` + `Syntax`** — SGML declaration + concrete syntax, with the XML
   reference defaults (delimiters, name chars, quantities). Enough for the
   implied XML declaration the corpus uses.
3. **DTD data structures** — `Dtd`, `ElementType`, `AttributeDefinition`(+List),
   `Notation` (the declaration-dump target).
4. **Content model** — `ContentToken`/`ModelGroup` tree → DFA compile.
5. **Declaration parser** — ELEMENT/ATTLIST/ENTITY/NOTATION over a token stream
   → builds the `Dtd`.

### Memory & residency

Same one-region-per-run rule. The `Dtd` and its element/attribute/notation
tables, the content-model token trees and their compiled DFA states, all live
to run end → `Owner<T>` fields become plain fields, shared refs are borrowed
pointers. Content-model DFA states are a fixed graph built once per element
type; index leaf tokens densely (arena arrays).

### Type inventory & MI (Stage 3)

No true MI in the C# port; three C++ MI sites resolved by the mirror and
followed here: `ElementType : Named + Attributed` → an `Attributed` member;
`Notation : EntityDecl + Attributed` → EntityDecl base + inline attributed;
`ParserState`'s C++ `ContentState + AttributeContext` → linearized
(`ContentState : AttributeContext`). Key shapes (C# LOC):

- **`Sd`** (822) — feature flags (OMITTAG/SHORTTAG/…), capacities, quantities,
  charset, `execToInternal`, `www()`. **`Syntax`** (1019) — char-class sets +
  `categoryTable` (per-char Category), general delimiters, quantities
  (`referenceQuantity_`), namecase subst, standard functions, markup-scan table;
  the `Syntax(Sd)` ctor builds the reference/XML defaults.
- **Scanner:** `Recognizer`(100, trie-driven `recognize(InputSource)`) built by
  `TrieBuilder`(206)/`Trie`(169)/`Partition`(245) from `ModeInfo`(335)+`Syntax`;
  `Mode`(74)/`MarkupScan`(21) enums; `ParserState.getToken(Mode)` is the choke
  point.
- **DTD:** `Dtd`(451, element/entity/notation/rankstem/shortref tables),
  `ElementType`(389: `ElementDefinition` owns `CompiledModelGroup`, omit flags,
  inclusions/exclusions; `RankStem`; `ElementType`), `Attribute`(1824: declared
  values + `AttributeDefinition` subclasses + `AttributeContext:Messenger`),
  `AttributeList`(587), `Notation`(92), `ShortReferenceMap`(105),
  `Attributed`(41).
- **Content model + DFA:** `ContentToken`(1283: `ModelGroup`(And/Or/Seq),
  `LeafContentToken` indexing, `FirstSet`/`LastSet`, `CompiledModelGroup.compile`
  = the DFA builder, `AndState`, `MatchState`), `Group`(292 parse scratch),
  `ContentState`(216, open-element stack).
- **Parser:** `Parser.cs`(11801, = `ParserState`(1627 god-object) + all parse
  methods): `parseSgmlDecl`→Sd/Syntax; `doProlog`/`doDeclSubset`;
  `parseElementDecl`/`parseAttlistDecl`/`parseEntityDecl`/`parseNotationDecl`/
  `parseShortrefDecl`; `parseParam`(the param workhorse); helpers `Param`(388),
  `SdParam`(111), `SdBuilder`(36), `ParserOptions`(235).

Port order (map's): Tokens → Sd+Syntax (**Increment A**) → content-model DFA
(**Increment C**) → scanner (**Increment B**, done) → attributes → Notation →
Dtd → ContentState → ParserState → Parser (by section: parseSd → parseParam →
parseDecl → prolog). Dtd/ParserState/Parser are the integration tail, last.

### Landed (Stage 3, Increment B — scanner)

JIT-green (`tests/opensp/run.sh`), emission-neutral (`cycle.sh` IDENTICAL):
- **`ISet.scaly`** — `ISet<Char>` interval set (sorted, coalesced, disjoint
  ranges) over u32, live-count backed (Array cannot shrink; addRange/remove
  delete ranges).
- **`Syntax` (extended)** — DelimGeneral/Set/StandardFunction enums, the
  reference concrete-syntax general delimiters (const `DELIM_LEN`/`DELIM_CHARS`
  tables, incl. WWW HCRO/NESTC), reference standard functions (RE=13/RS=10/
  SPACE=32), and the 11 reference character sets (`char_set(i)`). These are the
  reference SEED; the SD-declaration parser overrides them per custom syntax.
- **`Sd` (extended)** — reference/SHORTTAG feature-flag accessors
  (`start_tag_empty`/`concur`/`link`/`keeprsre`) that ModeInfo consults.
- **`InputSource` (extended)** — the token-scanning cursor
  (`start_token_no_multicode`/`token_char` [Xchar eE=-1]/`end_token`/
  `current_token_length`), multicode=false path only.
- **`Partition.scaly`** — the char→EquivCode map. Scope: 0..255 (the reference
  8-bit syntax, Increment-A's convention); an O(256) class-id refinement
  (`resplit`) replaces C++'s interval-list EquivClass machinery — the observable
  map/per-set code lists are identical (codes are internal labels). Delimiter
  namecase folding is not applied (match-as-spelled).
- **`Trie.scaly`** — flat page-hosted `Node` (C++ Trie/BlankTrie folded to one
  tagged struct) + `TrieBuilder` (recognize / recognize_set / recognize_ee /
  extend / force_next / set_token). DEFERRED with the Dtd increment: the
  BlankTrie / B-sequence machinery (reached only via shortref delimiters
  against a DTD).
- **`ModeInfo.scaly`** — the 45 scanner Modes, the 62-entry master token table
  (`PackedTokenInfo`, mode membership as a u64 bit vector) and its per-mode
  `next_token` iterator; `missing_requirements` drops feature-gated tokens.
- **`Recognizer.scaly`** — the trie-driven `recognize(InputSource)` (greedy
  walk + `end_token` longest-prefix commit) and the `build_recognizer` driver
  (Parser::compileModes for one mode, no DTD/shortref): two ModeInfo passes →
  Partition + TrieBuilder → Recognizer. Integration test tokenizes a
  content-model group (grpMode), a start-tag / data / `<`-as-data / whitespace
  in element content (econMode), and markup-declaration pieces (mdMode).

**Traps hit:** array-literal globals need a trailing comma before `]`
(`u8[]`/`u32[]` both fine); TokenInfo fields `type`/`set`/`function` collide
with keywords (renamed `kind`/`set_idx`/`func_idx`); `^_rp` cannot name the
caller page (leading `_` won't lex) — page-host tests via a `StringC` anchor +
`Page.get`. Sibling-module `define` constants (tokens, delimiter/set indices,
mode ordinals) are visible unqualified across the package.

### Landed (Stage 3, Increment C — content-model DFA)

JIT-green (`tests/opensp/run.sh` → `PASS`, 50 assertions):
- **`ElementType.scaly`** — minimal seed (identity + dense `index`, all the DFA
  needs); the full `ElementType` (389 LOC) lands whole in the Dtd increment.
- **`ContentToken.scaly`** — Clark's position-automaton construction:
  `analyze`/`analyze1` (FIRST/LAST sets, AND-depth bookkeeping),
  `addTransitions` (adjacent-position follow threading), `finish`/`andFinish`
  (follow dedup+compaction → element→transition table, PCDATA-reachability,
  ambiguity detection), `CompiledModelGroup.compile`, and the parse-time
  `AndState`/`MatchState` runtime (`tryTransition`/`tryTransitionPcdata`/
  `isFinished`/`computeMinAndDepth`). Tests cover SEQ, optional members, OR
  choice, `+` repetition, mixed content `(#PCDATA|a)*`, AND groups (both
  orders + double-member rejection), and a nested OR-in-SEQ (recursion +
  branch mutual-exclusion). Emission-neutral (`cycle.sh` IDENTICAL).

**Port shape:** the C++ `ContentToken` class hierarchy (ContentToken →
ModelGroup → And/Or/Seq; ContentToken → LeafContentToken →
Pcdata/Initial/Element) is FLATTENED into one page-hosted `Node` struct tagged
by `kind`/`connector`. Rationale: `analyze`/`finish` mutate a shared node graph
in place and cross-link nodes by pointer, which a Scaly union models awkwardly
(no in-place field mutation across variants); the tag replaces C++ virtual
dispatch, and the whole graph lives on the run's compile page. Growable follow
sets → `Array` with a separate `n_follow` live-count after compaction (Array
has no shrink). Deferred (rare SGML, absent from the XML/model-DTD corpus):
`DataTagGroup`/`DataTagElementToken`. **Mutation trap confirmed:** through a
`pointer[Node]` use PLAIN `.` (`set p.field: v`) — the explicit-deref
`(*p).field` form silently mutates a value COPY (root_pages.scaly's note).

### Landed (Stage 3, Increment — attributes)

JIT-green (`tests/opensp/run.sh` → `PASS`), emission-neutral (`cycle.sh`
IDENTICAL). Ports `Attribute.cs` (1824), `AttributeList.cs` (587),
`Attributed.cs` (41):
- **`Attribute.scaly`** — the declared-value classification and the produced
  value/semantics/spec:
  - `DeclaredValue` — the C++ `DeclaredValue → Cdata / Tokenized → Group →
    NameTokenGroup / Notation, Entity / Id / Idref` hierarchy flattened to one
    tagged struct (`dv_kind`); the `TokenizedDeclaredValue` ctor's
    initial/subsequent CATEGORY selection per `TokenType`, `tokenized`/`isId`/
    `isIdref`/`isNotation`/`isEntity`/`containsToken`, and the full
    `buildDesc` → `AttributeDefinitionDesc.declaredValue` mapping (the
    `type + (isList ? names : name)` arithmetic plus the id/idref/notation/
    nameTokenGroup overrides).
  - `AttributeDefinition` — `Required / Current / Implied → Conref, Default →
    Fixed` flattened (`ad_kind`); `isConref`/`isCurrent`/`isFixed`, name/
    origName, `setSpecified`/`isSpecified`, `buildDesc` → `DefaultValueType`,
    `getDesc` (both halves), and `makeMissingValue`'s value-selection branch
    (driven by the context).
  - `AttributeValue` — `Implied / Cdata / Tokenized → Data` flattened;
    `info` → `Type`, `string`, and `TokenizedAttributeValue::token(i)` /
    `nTokens` token splitting over a `spaceIndex` vector.
  - `AttributeSemantics` — `Entity / Notation` flattened; entity/notation held
    by IDENTITY (borrowed `pointer[void]`, their concepts land with the Dtd).
  - `Attribute` — the per-spec slot (specIndexPlus/value/semantics).
  - `AttributeContext` — the `Messenger` base as a concrete synthetic context
    (validate/mayDefaultAttribute flags + a message counter + cached implied
    value); the live parser subclass (id table, entity/notation lookup,
    current-value store) lands with the parser stage.
- **`AttributeList.scaly`** — `AttributeDefinitionList` (append with id/
  notation/current index tracking, `attributeIndex`/`tokenIndex`/
  `tokenIndexUnique`), `AttributeList` (init/size/name/value/specified/id/
  idref/getId, `setSpec` spec-index tracking + duplicate detection, `finish`'s
  missing-value fill + grpcnt/conref checks), and `Attributed`.

**Minimal seeds & deferrals** (port-order faithful, documented in-file):
- `Text` — a minimal seed (`StringC` + `fixedEqual`); the full content Text
  (`TextIter`/`TextItem`, per-char locations, subst tables) lands with the
  parser stage, which is also where the message-emitting value
  NORMALISATION/VALIDATION (`makeValue`'s category/length checks, allowed-value
  and entity/notation/id resolution through the live context) and the
  `setValue`/`recoverUnquoted`/`handleAsUnterminated` + `makeSemantics` paths
  are driven. This increment ports the type structure, the pure classification/
  `buildDesc` logic, missing-value selection, and token splitting.
- `DataDeclaredValue`/`DataAttributeValue` fields (notation + attribute list
  for NDATA) reserved in the tag space, resolution deferred to the parser.
- `out` params modelled as pointer-out (`isSpecified`) or a `-1` sentinel
  return (`attributeIndex`/`tokenIndex`).

**Trap hit:** `StringC.substr` added (needed by `token(i)`) — allocates the
slice on the returned value's own page, clamping out-of-range slices to empty.

### Landed (Stage 3, Increment — notation)

JIT-green (`tests/opensp/run.sh` → `PASS`), emission-neutral (`cycle.sh`
IDENTICAL). Ports `Notation.cs` (92) + the `EntityDecl.cs` metadata a notation
needs:
- **`Notation.scaly`** — a NOTATION declaration: name, optional `ExternalId`,
  `defined` flag, declaration location, and (because a notation is `Attributed`)
  its data-attribute `AttributeDefinitionList`. `setExternalId` records the id +
  marks defined + stamps the location; `systemId`/`publicId` presence+value come
  from the external id; the `Attributed` half (`get`/`setAttributeDef`) is inline.

**MI resolution** — C++ `Notation : EntityDecl + Attributed`. Following the C#
port's lead, the `EntityDecl` declaration metadata (declType/dataType/dtd-scope/
defLocation) and the `Attributed` member are FOLDED INLINE. A notation's declType
is always `notation` (new `DCL_*` constants) and dataType always `ndata`
(`DT_NDATA`, reused from the Entity module), so those are fixed accessors, not
stored fields. Notations are page-hosted (referenced by identity from
`NotationAttributeSemantics` and the DTD notation table).

**Deferrals:** the full shared `EntityDecl` base (reused by the entity table) +
entity-side decl metadata land with the Dtd/entity-table increment;
`generateSystemId` (catalog lookup of a notation system id) needs the live
`ParserState` + `EntityCatalog` and lands with the parser stage.

### Landed (Stage 3, Increment — dtd)

JIT-green (`tests/opensp/run.sh` → `PASS`), emission-neutral (`cycle.sh`
IDENTICAL). The convergence increment: the `Dtd` tables + the pieces they own.
Ports `Dtd.cs` (451), the full `ElementType.cs` (389), `ShortReferenceMap.cs`
(105), and the deferred `Trie`/`TrieBuilder` BlankTrie machinery.

- **`ElementType.scaly` (grown from the Increment-C seed)** — the full element
  layer: `ElementDefinition` (owns the `CompiledModelGroup`, omit-tag flags,
  declared content, inclusions/exclusions/rank stems; `computeMode` derives the
  two content modes from the declared content + PCDATA reachability, reading
  ModeInfo's mode constants), `RankStem` (name + dense index + definition list),
  and `ElementType` itself (StringC name, dense `index`, `def_index`, borrowed
  `ElementDefinition` pointer, `ShortReferenceMap` pointer, inline `Attributed`
  member). The DFA's identity + `index` contract is byte-stable: the
  construction shape `ElementType^host(name, index)` and `get_index` are
  unchanged (only `name` moved byte-String → StringC — see the name seam below).
- **`ShortReferenceMap.scaly`** — a named SHORTREF map: per shortref index a
  general-entity NAME (`name_map`) and, once resolved, the borrowed `Entity`
  (`entity_map`); `defined`/`used`/`defLocation` bookkeeping. `defined()`
  mirrors the C++ `nameMap_.size() > 0` (a set-but-empty map counts).
- **`Dtd.scaly`** — the run's central tables: element types, entities (split
  general/parameter), notations, rank stems, shortref maps, plus the shortref
  string-interning table and the dense-index allocators (element type /
  definition / current attribute / attribute-definition list). The document
  element type takes index 1 (0 reserved for #PCDATA) and is auto-inserted by
  the ctor. Full lookup/insert/remove API + `is_base`/`instantiate` + implicit
  element/notation attribute defs.
- **`Trie.scaly` (BlankTrie machinery, un-deferred)** — the `blank`
  fields (`additional_length`/`max_blanks_to_scan`/`code_is_blank`) fold into
  the flat `Node`; `recognize_b`/`do_b`/`copy_into` build a shortref B-sequence
  (blank-run) branch, and `force_next` pushes a BlankTrie down into its
  blank-code children (first child moves it, the rest deep-copy via `copy_node`)
  and grafts its token structure back with `copy_into`. Unit-tested
  programmatically (a `"B"` shortref → token, then a manual `force_next` to
  observe the migration), not via SGML text.

**Port-shape decisions:**
- **Tables = flat Array-of-pointers, linear scan by StringC name.** The C++
  `NamedTable`/`NamedResourceTable` use a hash for scale; the `NamedTableIter`
  is not load-bearing for the lookup/insert API this increment unit-tests on
  small hand-built DTDs (the perf path is the Parser increment's concern, where
  real corpus DTDs land). Insertion-order iteration (C++'s is hash-bucket
  order) is not semantically observable through lookups. `remove` tombstones
  the slot (`Array` cannot shrink); lookups skip null slots.
- **EntityDecl base stays FOLDED; the entity table keys on explicit
  `is_parameter`.** Resolving the notation increment's open question: no shared
  `EntityDecl` concept is introduced. C++'s `lookupEntity`/`removeEntity`
  already take `isParameter` explicitly; only `insertEntity` derived it from
  `declType()`. Since the `Entity` union carries no declType, `insert_entity`
  ALSO takes `is_parameter` explicitly (the parser knows it — it parsed the
  `%`), faithful to the two-table param/general split.
- **Name seam reconciled to StringC.** `ElementType`, `RankStem`, and the
  `Entity` union's names moved byte-String → StringC (Notation was already
  StringC), so every DTD table keys uniformly on StringC — matching the
  scanner (which produces StringC names) and the attribute/notation lookups.
  `Entity.get_name` (choose over the arms) was added; the 4 `ElementType^host`
  construction sites in `ContentToken`'s test now pass `StringC(...)`.

**Deferred to the ParserState/Parser increment (need the live parser to drive
them):** `ContentState` (open-element stack — it constructs a `ContentToken`
model group, builds an `ElementDefinition`, and depends on the not-yet-ported
`OpenElement`, and is the `AttributeContext → ContentState → ParserState`
linearization anyway); `Dtd.setDefaultEntity`'s LPD/defaulted-entity fan-out
(needs the entity-decl `defaulted` flag + `generateSystemId`); the
`Syntax::isValidShortref` gate on shortref interning (the parser validates
before interning — `intern_shortref` is the pure table op). The `Dtd` data
structures + their construction/lookup API are complete and unit-tested here.

### Landed (Stage 3, Increment A)

JIT-green (`tests/opensp/run.sh` → `PASS`):
- **`Tokens.scaly`** — the full 61-token table + `tokenFirstShortref` (module
  constants, visible unqualified to sibling modules).
- **`Sd.scaly`** — minimal reference `Sd`: identity `exec_to_internal`, `www()`.
- **`Syntax.scaly`** — the reference-syntax `Syntax(Sd)` character
  classification (256-entry category table: letters→nameStart, digits→digit),
  namecase `fold` (lc→uc subst), reference quantities, `is_name_start_character`/
  `is_name_character`/`is_digit`/`is_hex_digit`/`get_quantity`, and
  `add_name_start_characters`/`add_name_characters` (the SD/XML naming
  extensions). Delimiters/standard-functions/s-sets/reserved-names/markup-scan →
  Increment B (scanner). Emission-neutral (`cycle.sh` IDENTICAL).

**Parser trap hit:** a multi-line single-expression function body (an `or`
chain on continuation lines) breaks the Scaly parser with a *misleading* error
at the enclosing concept header — keep a braceless body on one line, else use
`{ … }` with explicit `return`s.

### Landed (Stage 2)

All green through the JIT (`tests/opensp/run.sh` → `PASS`):

- **`Storage.scaly`** — `Storage` union `Literal`/`OsFile`; `read`/`exists`/
  `resolve` (OsFile via `scaly.io.File` + `Path`), `type_name`.
- **`ExternalId.scaly`** — public/system id holder (byte `String` ids).
- **`EntityCatalog.scaly`** — `CatalogParser` (comment/quote/name tokenizer) for
  PUBLIC/SYSTEM/DOCTYPE/ENTITY/SGMLDECL/OVERRIDE/CATALOG; `EntityCatalog`
  first-match `lookup_public`/`_system`/`_doctype`/`_entity` and `lookup(ExternalId)`
  (PUBLIC → SYSTEM → catalog-relative SYSTEM fallback), catalog-dir-relative.
- **`EntityManager.scaly`** — `open(sysid, storage, cs, origin)`: read bytes →
  CodingSystem decode → region Char buffer → `InputSource` (Char buffer on the
  byte buffer's page).
- **`Entity.scaly`** — `InternalEntity`/`ExternalTextEntity` + `Entity` union;
  `stack()` = normalReference: internal pushes its own text as an InputSource,
  external resolves via `catalog.lookup` + `manager.open`; the pushed source's
  origin carries the reference `Location` (nested tracking verified).

Deferred by scope (documented above, not blockers): formal-public-id parsing
(`PublicId` FPI/URN); `ParsedSystemId` `<osfile>` FSI syntax + record
normalization; the Fd/URL/WinInet/Stdio storage managers; DELEGATE/DTDDECL/BASE
catalog directives + nested-CATALOG following; data-entity events + recursion
guard. **Corpus-wide entity-graph resolution** (the roadmap exit) needs the
prolog/DTD parser to drive it and thus couples with Stage 3; Stage 2's gate is
the machinery + synthetic resolve-and-dump, all deterministic and
filesystem-free (the `OsFile` live-read path is a thin `scaly.io.File`
delegation, exercised by the local corpus run once the DTD parser feeds it).
Emission-neutral (`tools/cycle.sh` IDENTICAL).
