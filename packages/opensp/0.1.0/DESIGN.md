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
