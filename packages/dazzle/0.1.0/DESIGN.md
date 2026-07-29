# dazzle package — Stage 6a design note

Stage 6a of [ROADMAP-dazzle.md](../../../ROADMAP-dazzle.md): faithful port of
the openjade style engine, interpreter included; the JIT (6b) comes later
behind the same `Expression` seam, with this interpreter as its differential
oracle. Port sources: `~/repos/openjade-net/src/OpenJade/{Grove,SPGrove,Style,Jade}`
(C# mirror, structurally closest), `~/repos/dazzle-net/src/lib/` for dazzle's
own extensions, `upstream/openjade` C++ as ground truth on any divergence.

## Seam to opensp

The engine consumes the `packages/opensp` Event stream — the same seam the
ArcEngine uses (`ps.events` via `n_events()`/`get_event(i)` after a parse).
`GroveBuilder` builds the grove from Events; `DssslSpecEventHandler` parses
the `.dsl` (a style-sheet-DTD SGML document) through the same opensp parser.

## Baseline (measured 2026-07-17, reference C++ `dazzle`, warm cache)

Gate corpus decided 2026-07-17 (Ralf): one tiny smoke module, three large
representative modules, one module on the second database schema — all from
the model-DTD codegen family (`-G -t sgml -d map.dsl <module>.xml`,
`SP_CHARSET_FIXED=YES SP_ENCODING=XML`, cwd = the script's directory; the
concrete module list lives in the gitignored corpus map, never here). Later
add one service-codegen run (the roadmap exit names both stylesheet families).

- smoke module: 0.06 s, 17 files, 92 K
- large modules: 0.10 s / 672 K, 0.11 s / 1.1 M, and the largest
  0.33–0.35 s / 3.6 M with **max RSS ≈ 95 MB** (this is Clark's engine WITH
  its mark-sweep Collector — the reference number for risk-register item 1;
  our arena high-water at 6a exit is judged against it)
- other-DB module: 0.07 s / 1.2 M
- every module emits 17 files; rc=0 even when X-class errors (missing IDREF
  targets) are reported; stdout empty, stderr empty on the clean runs

Reference-behavior findings the port must reproduce:

- **The directory flow object mkdir's (0755).** SUPERSEDED note (2026-07-18):
  the earlier measured baseline read "no mkdir" while the C++ dazzle extension
  sources were not checked out. They now are (`~/repos/dazzle/jade/
  TransformFOTBuilder.cxx:600` calls `mkdir(dirName, 0755)` unconditionally) and
  the C# mirror agrees (`Directory.CreateDirectory`); per rule zero the port
  follows the located C++/C# source, so `startDirectory` creates the directory.
  (Decision Ralf 2026-07-18. If a future re-measurement of the reference binary
  shows no-mkdir, revisit — the two oracles disagreed here.)
- `-t sgml` selects the **TransformFOTBuilder** (JadeApp backend switch), not
  SgmlFOTBuilder (that one renders an FOT dump).

## Where the dazzle extension lives

The `directory` flow object is NOT in openjade-net (upstream openjade's
`TransformFOTBuilder.cxx` has no trace); its portable mirror is
`dazzle-net/src/lib/TransformFOTBuilder.cs` (`DirectoryFlowObj`, pubid
`UNREGISTERED::Dazzle//Flow Object Class::directory`, a `directoryStack_`
prefixing entity filenames). **RESOLVED 2026-07-18: the C++ dazzle extension
sources ARE checked out** — `~/repos/dazzle/jade/TransformFOTBuilder.{cxx,h}`
(with the `DirectoryFlowObj` + `startDirectory`/`startEntity`); this is now the
ground-truth oracle for the sink, dazzle-net the structural mirror.

## RBMM mapping

- **One arena region per run** (roadmap doctrine). `Collector.Object` base →
  plain page-hosted structs; Clark's `Collector` interface survives only as
  the allocation seam (objects are `make`d on the run page). No GC in v1;
  the 6a-exit high-water measurement against the 95 MB reference decides
  whether the ladder's scratch-region or Collector rung is needed.

  **6a-exit measurement (2026-07-19, `tests/dazzle/memhw.sh`).** Peak RSS over
  the in-repo mkp DSSSL codegen corpus (the five `-G -t sgml -d` runs that
  `tests/dazzle/codegen/run.sh` proves byte-identical):

  | run | dazzle | openjade | ratio |
  |---|---|---|---|
  | scaly.dsl → parser/Syntax/grammar | 39.4 MB | 19.8 MB | 2.0× |
  | test-expressions.dsl (69 tests) | 41.2 MB | 16.4 MB | 2.5× |
  | test-definitions.dsl (15 tests) | 27.8 MB | 15.8 MB | 1.8× |
  | test-choose.dsl (14 tests) | 28.6 MB | 15.6 MB | 1.8× |
  | test-controlflow.dsl (28 tests) | 33.1 MB | 15.9 MB | 2.1× |

  High-water **41.2 MB** (vs a ~9 MB fixed floor on a trivial doc). The 1.8–2.5×
  overhead over openjade's mark-sweep GC is the expected arena-retention cost
  and is negligible in absolute terms. Retention is **sub-linear in rule count**,
  not the feared O(n²): per-test cost *falls* as the doc grows (1.40 MB/test at
  14 tests → 0.47 MB/test at 69) — an O(n²) churn would make it rise.

  **Verdict for risk-register item 1: arena-per-run is sufficient at this scale;
  neither the scratch-region (rung ii) nor the Collector (rung iii) is needed.**
  Caveat: this is the project's own literate/grammar corpus. The real-world
  service-codegen family (the 3.6 M-output module behind the 95 MB openjade
  reference above) uses named-let-over-node-list idioms more heavily and is not
  in this checkout — re-run `memhw.sh` against it when those stylesheets are
  available (Stage 4/9). Rung (iii) remains the bounded fallback, so this is a
  cost risk, never an architectural one.
- **`eq?` / identity-keyed tables rely on stable addresses** — sound as long
  as we do NOT copy objects between regions. Any future scratch-region
  copy-out must exempt identity-bearing objects (design-note item for that
  ladder rung, not for v1).
- **ELObj hierarchy (~40 subclasses) → one big union** (`choose`, no casts),
  per the established opensp Entity/CodingSystem pattern; the `NodeListObj`
  and `SosofoObj` sub-hierarchies become nested unions. Insn (~74 classes)
  likewise.
- Interning tables (`SymbolObj`/`Identifier`/`KeywordObj` by name) and unit
  tables: hash tables on the run page.
- VM stacks (value stack, `ControlStackEntry` frames): growable arrays on the
  run page; `needStack`/`growStack` ported as-is.

## Multiple-inheritance sites

Resolved case-by-case as encountered, recorded here per increment (the
opensp precedent: the C# mirror had already flattened every true MI site).
Known candidates: `VM : EvalContext` + Collector tracing (composition),
`Interpreter` mixing Messenger/Collector (composition, like MessageReporter).

## Port order (increments; each lands JIT-green in tests/dazzle/run.sh,
emission-neutral — `cycle.sh` IDENTICAL)

1. **ELObj value model** — core objects (nil/true/false/unspecified, pair,
   string, char, symbol, keyword, integer, real, quantity/length, vector),
   printer, `equal?`/`eqv?`, interning. Harness: construct/print/compare.
2. **SchemeParser** — the datum/expression reader (tokenizer over `StringC`),
   quasiquote desugar; plus `DssslSpecEventHandler` (style-sheet DTD parse,
   part assembly, external-entity `.scm` inclusion) over opensp Events.
   Harness: parse the corpus stylesheets' text, dump datums.
3. **Expression + Insn/Insn2 + VM + Interpreter core** — compile Expressions
   to Insn chains, run the VM (frames, closures, boxes, varargs, keywords,
   TailApply = the TCO the JIT must later reproduce), `define`/`lambda`/
   `let`/named-let/`cond`/`case`/`quasiquote`; primitives from
   `Primitive.cs` by the measured demand list of the corpus stylesheets
   (~250–300 of ~543), not ISO order. Harness: eval snippet corpus.
4. **Grove** — `Node`/`NodePtr`/`NodeList` + property machinery +
   `GroveBuilder` over the opensp Event stream. Harness: grove dumps of
   corpus documents.
5. **Style machinery** — `ProcessingMode`, `Pattern` matching, construction
   rules, `StyleEngine`, Sosofo objects, `process-children`, modes.
6. **FOTBuilder + TransformFOTBuilder** — `entity`/`entity-ref`/`element`/
   `empty-element`/`document-type`/`processing-instruction`/
   `formatting-instruction` + dazzle's `directory` flow object (no-mkdir
   semantics per the oracle).
7. **CLI** — the `dazzle` driver (`-G -t sgml -d -V -o`, catalogs, env).
   Gate: smoke module byte-identical, then the full five-module gate corpus
   (stdout/stderr/rc/all 17 files each), timing + memory high-water recorded
   here.

## Deliberate non-goals in 6a

- No `call/cc` (loud unsupported error; zero corpus users).
- No JIT — that is 6b, behind the `Expression` seam established here.
- `LangObj`/`MacroFlowObj` etc. ported only if the demand list pulls them in.
- ~~No print path (`InheritedC`, RTF/TeX/MIF/HTML backends) — Stage 9.~~
  SUPERSEDED by the widened 6a exit (REPRODUCTION.md step 2, started
  2026-07-27): the `-t fot` backend + the inherited-characteristics
  foundation land in 6a; see Inc 8 below.

## Inc 8 — `-t fot` backend (SgmlFOTBuilder) + inherited-characteristics foundation

Reference: `jade/SgmlFOTBuilder.cxx` (2824 LOC) fed by the style engine's
IC system (`style/Style.{h,cxx}`, `style/InheritedC.cxx`,
`style/FlowObj.cxx`); backend selection `jade.cxx makeFOTBuilder` —
`-t fot` writes to a FILE (default `<docbase>.fot`), unitsPerInch=72000
(millipoints; JadeApp ctor `u`), NO extension flow objects, output through
`RecordOutputCharStream(EncodeOutputCharStream(...))`.

Slice 1 (this increment) — foundation, validated byte-identically against
the reference binaries on toy stylesheets (`tests/dazzle/fot/`):

- **`Style.scaly` (new module):** `InheritedC` as a kind-tagged record
  (bool/length/length-spec/symbol/string/integer/public-id — the six
  generic classes of `InheritedC.cxx`; specials Color/Border/Rule deferred),
  conversion + `invalidCharacteristicValue` per the reference converters;
  `StyleSpec`/`VarStyleObj` (ELObj arm `Style`, opaque spec pointer),
  `StyleStack` with the `InheritedCInfo`/`PopList` level machinery
  (`pushContinue` first-wins dedup per level, `pushEnd` emits the set*
  calls in spec order; the `dependencies`/`actual-*` machinery and style
  RULES are deferred with the `inherited-*`/`actual-*` primitives).
- **Lazy IC evaluation (2026-07-28, superseding slice 1's eager collapse):**
  non-constant IC value exprs compile to standalone `VarInheritedC` code
  against a closure env of the marked bound vars (`StyleExpression::
  compile`); the make/style insns capture those vars into a display array +
  the current node (`VarStyleRec` — the VarStyleObj payload behind the
  two-pointer ELObj Style arm) and carry compile-time-prebuilt
  `force_specs`/`specs` arrays (`force!<name>` keys included). Push-time
  evaluation, caching and dependency tracking live in
  `StyleStack`/`InheritedCInfo`/`PopList` (Style.scaly) with the VM-facing
  glue (`ic_value_of`/`eval_spec_value`/`stack_inherited`/`stack_actual`/
  `resolve_set`) in VM.scaly — Style cannot import VM (VM→Insn→Style).
  `inherited-<name>`/`actual-<name>` primitives are installed per registry
  entry (prefix-strip recovers the characteristic); `actual-*` circularity
  is the `actualLoop` message; outside a characteristic value the
  primitives error `notInCharacteristicValue`. Arithmetic (`+ - * /`)
  tracks quantity DIMENSIONS per the reference (Plus/Minus demand one
  shared dimension; Multiply/Divide add/subtract them; exact dim-1 results
  are LengthObj) — the pre-existing dimensionless collapse made every
  computed length invalid. The dsssl2 trailing-'?' alias is NOT installed
  (reference gates it on the unported `-2` flag).
- **`Identifier.inherited_c` slot** (the S62 struct-growth trap measured
  GONE 2026-07-27: Identifier/FlowObj/ProcessContext growth probes all
  green — suites + codegen byte-identical); FOT symbols installed with
  their `c_value` codes (the full 120-entry FOTBuilder::Symbol enum;
  faithful quirk: `symbolBevel`'s name is "join").
- **IC registry:** `installInheritedCs` ported with the reference INITIAL
  values (the inherited-* fallback; upi=72000), the maybe-integer entries
  (expand-tabs?/hyphenation-ladder-count), the 14 IgnoredC entries
  (accepted, never rendered), the Border entries (table-border +
  cell-*-border with the canned border-present styles), and (2026-07-28)
  color/background-color (ColorC/BackgroundColorC — `#RRGGBB`, `"false"`
  background), min-pre-line-spacing/min-post-line-spacing/min-leading
  (GenericOptLengthSpecInheritedC — the `#f` arm prints ` name"false"`
  with the reference's missing '='), escapement-space-before/-after
  (GenericInlineSpaceInheritedC — inlineSpaceC never closes its quote,
  faithful) and inline-space-space (GenericOptInlineSpaceInheritedC —
  setInlineSpaceSpace is not overridden in the reference SgmlFOTBuilder,
  so a set renders nothing). Still deferred: Rule (fraction-bar) and
  GlyphSubstTable — using those keywords is `invalidStyleKeyword` until
  their increment.
- **Length-spec / space / color values (2026-07-28):** new ELObj arms
  LenSpec (the engine 3-vector `EngLenSpec` — length, display-size
  factor, table-unit factor; produced by `display-size`/`table-unit` and
  by `+ - * /` over length-specs per the reference spec paths, incl. the
  quirks: only the FIRST arg of `* /` may be a spec, the not-a-number
  error always names argument 1, the Divide loop's not-a-quantity error
  names argument 0), DispSpace/InlSpace (opaque Style.DisplaySpace/
  InlineSpace payloads from the `display-space`/`inline-space` primitives
  with min:/max:/conditional?:/priority: keyword scans), Color and
  ColorSpace (`color`/`color-space` — the four Device families plus the
  full CIE LUV/LAB/ABC/A machinery with the XYZ phosphor-matrix
  conversion and decode-function calls on a fresh VM). TableColumnNIC
  width is a TableLengthSpec (the table-unit factor prints "%.2f*", the
  display-size factor "%.2f%%" — unlike the plain LengthSpec operator
  whose factor sprintf is dead code).
- **`MakeExpression` split** (Expression.cxx 1250–1420): per key —
  FO-class NIC (DisplayNIC family for paragraph/paragraph-break/
  display-group; InlineNIC accepted-and-dropped for line-field, its fot
  dump ignores them) / `use:` / IC (via `ident.inherited_c`) / else
  `invalidStyleKeyword`. Transform FO classes keep the existing collapsed
  path byte-identically.
- **Lazy NIC evaluation (2026-07-28, the full reference shape):**
  CONSTANT NIC values (display, table, header/footer sosofos) convert at
  COMPILE into insn prototypes (`applyConstNonInheritedCs`: message once,
  anchored at the value expression); non-constant ones compile into a
  side chain of SetNic insns (`compileNonInheritedCs`) that the flow
  object carries (`FlowObj.nic_code`) and `ProcessContext.resolve_nics`
  evaluates PER PROCESS on a fresh deep copy — after the style push
  (`SetNonInheritedCsSosofoObj::process`: startFlowObj, pushStyle,
  resolve, processInner, popStyle), against the CURRENT style stack
  (inherited-*/actual-* in NIC values read the pushed context) and the
  make-time display/node. The chain executes in REVERSE key order and an
  error VALUE aborts the whole resolve — the FO then emits nothing while
  its push/pop bracket still closes (bad5 pins all of this). The
  table-cell pseudo NICs (column-number/spans/starts-row?/ends-row? —
  the cell's pushStyle needs them) evaluate at CONSTRUCTION on the main
  chain (`SetPseudoNonInheritedCInsn`), only n-rows-spanned is lazy.
  Rule bodies compile in REVERSE file order per mode (the reference
  elementRules_ IList prepends) — observable through compile-time
  diagnostics ordering.
- **`SgmlFOTBuilder.scaly`:** ctor/dtor frame (`<?xml version="1.0"?>`,
  `<fot>`/`</fot>`), `ics_` characteristic buffer + `outputIcs`, Data
  escaping (`&amp;/&lt;/&gt;/&quot;` + `&#N;` ≥0x80), millipoint `Units`
  formatting, `displayNIC`/`displaySpaceNIC` dumps, `<text>`, sdata,
  startNode/endNode pending-anchor machinery (`<a name=…/>`), FOs:
  sequence, paragraph, paragraph-break, display-group, line-field.
  Remaining FO classes arrive by demand (simple-page-sequence + its
  header/footer six-way diff machinery next, then tables — dazzledoc).
- **ProcessContext:** `sgml_fotb` + `style_stack` fields; style push/pop
  brackets FO processing ONLY on the fot path (transform path untouched =
  Family A byte-safety; the reference pushes always, but its transform
  set* are no-ops — recorded deviation: `inherited-*` under `-t sgml/xml`
  errors `notInCharacteristicValue` where the reference would resolve; no
  corpus stylesheet uses it).
- **CLI:** `-t fot`, default output `<docbase>.fot`, unitsPerInch 72000
  for ALL backends per JadeApp (was 1440 — transform output never prints
  lengths; codegen suite + sweep must stay byte-identical), extension FO
  public-ids not installed under fot (a transform `declare-flow-object-
  class` then errors `unknownFlowObjectClass`, like the reference).

RBMM: the sink's buffers live on the sink's own page (S67 rope lesson:
memoize on `Page.get(this)`, never the caller host); StyleStack info array
on the run page, `InheritedCInfo`/`PopList` nodes in the current node's
eval scratch (they are popped inside the same bracket; inner→outer
pointers only). The lazy-NIC resolve copy, its fresh VM and every
converted NIC record live on the eval scratch too — their bytes reach the
sink inside the same bracket.

## RtfFOTBuilder (`-t rtf`) — design note (2026-07-29)

Reference: `~/repos/dazzle/jade/RtfFOTBuilder.cxx` (4391 LOC; C# mirror
`openjade-net/src/OpenJade/Jade/RtfFOTBuilder.cs`). Gate: dazzledoc
`dazzle -t rtf -d print/docbook.dsl dsssl.xml` → 1039007 bytes, stderr
empty, rc 0 (minted fresh from the reference binary; figures must be
present in the workdir — includePicture stats them). The reference RTF
uses only 75 distinct control words: NO borders, colors (colortbl empty),
underline/strike/smallcaps, math, grids, boxes, scores, cell backgrounds
or table headers (`\trhdr` absent — 27 trivial cells). Exercised: font +
char-format deltas, paragraph machinery, line-fields with tab leaders
(TOC), HYPERLINK/PAGEREF/INCLUDEPICTURE fields, bookmarks with
insertion-patching, 4 sections with the header/footer machinery, heading
styles, and the 12-entry EXTENSION characteristic table (page-number-
format/-restart?/-n-columns/-column-sep/-balance-columns?, sub/superscript
+ mark depths/heights, grid seps, heading-level) — active under rtf,
IgnoredC under fot (jade.cxx wires exts per backend).

Decisions:
- **Sink dispatch:** ProcessContext gains an `rtf_fotb` slot beside
  `sgml_fotb`; the ~53 styled-sink call sites go through per-method
  `sink_*` forwarders that branch once (fot vs rtf). The fot suites +
  dsssl.fot oracle gate the refactor (must stay byte-identical).
- **set_ic:** RtfFOTBuilder.set_ic dispatches on the STABLE registry
  index (0..164, reference install order) to the semantic setter bodies
  (specFormat_ field updates). Extension ICs: declare-characteristic on
  the rtf path matches the 12 reference pubids and installs a typed IC
  (bool/string/long/length conversions) carrying an ext-setter id;
  set_ic routes it. fot keeps the IgnoredC fallback.
- **unitsPerInch:** rtf runs the engine at 1440 (twips), per JadeApp.
  Interpreter length-typed IC initial values were transcribed at 72000
  — they become `upi*pt/72` computed (reference InheritedC.cxx shape:
  `(unitsPerInch()*10)/72`); byte-identical at 72000.
- **Capture (2026-07-29, SaveFOTBuilder call queue):** ports/connections
  capture recorded CALLS, not bytes — RTF output is delta-state
  (syncCharFormat) and first-use-numbered (fonts/colors), so spliced
  bytes are unsound in general. The seam lives at FotSink: while `save`
  is set every sink call is recorded onto that queue
  (`SaveFOTBuilder.scaly` — tag + deep-copied args, linked list with
  tail, the reference Call list); `emit_saved` replays through the sink,
  re-recording onto the outer queue when the sink is itself capturing
  (the reference emit-into-SaveFOTBuilder splice, expressed as a
  re-record so payload copies land on the outer queue's host).
  Over-connections and deep principal connections get the reference's
  ctor node wrapper (`make_node`: startNode/endNode around the replay).
  Deep-copy rules: set_ic ICs via `InheritedC.copy_for_save` (StringC
  payloads re-pinned, color ELObj rematerialized from color_rgb,
  InlineSpace record cloned, gst array copied); NIC records via their
  `copy` + re-pinned StringC/FotSym-name fields; `characters` copies its
  chars, `charactersFromNode` keeps the RAW grove pointer (reference
  shape — grove storage is run-lived and pointer adjacency drives the
  fot text-run regrouping). Gate that forced this: the Scaly docs RTF
  (CALS thead → 19 \trhdr header rows), byte-identical vs the
  reference binary; dsssl.fot/dsssl.rtf and all suites stayed
  byte-identical across the seam move.
- **Two-stream architecture:** body accumulates in a temp buffer (the
  reference TmpOutputByteStream block list collapses to one Array[u8] —
  no output-observable blocking); finish() writes the prolog (fonttbl in
  OpenSP HashTable ITERATION order — Torek hash h*33+c over Char, 8
  slots initial, doubling at used>=size/2, DECREMENTING probe, slot-order
  iteration, ported exactly — empty colortbl, stylesheet block) then
  copies the body patching INSERTION_CHAR ('\0') escapes: 'b' + two
  4-byte words = bookmark start/end pair emitted iff elementsRefed_
  contains (grove,element). WIN32 OLE arm not ported (mac reference
  binary has it compiled out).
- **JIS/doublebyte:** initJIS ports with CharsetRegistry JIS0208 if
  cheap at need; until a corpus doc contains CJK it is a LOUD stub
  (charTable rows only affect CJK codepoints).
- RBMM: all builder state on the sink's own page, per the S67 rule.
