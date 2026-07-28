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
  (expand-tabs?/hyphenation-ladder-count) and the 14 IgnoredC entries
  (accepted, never rendered). Still deferred to their features:
  Color/BackgroundColor/Border/Rule/GlyphSubst/OptLengthSpec/InlineSpace
  specials — using one of those keywords is `invalidStyleKeyword` until
  their increment.
- **`MakeExpression` split** (Expression.cxx 1250–1420): per key —
  FO-class NIC (DisplayNIC family for paragraph/paragraph-break/
  display-group; InlineNIC accepted-and-dropped for line-field, its fot
  dump ignores them) / `use:` / IC (via `ident.inherited_c`) / else
  `invalidStyleKeyword`. Transform FO classes keep the existing collapsed
  path byte-identically.
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
pointers only). Eagerly-evaluated IC values are converted to plain scalars
/ interned strings inside the make insn, so nothing IC-related escapes the
bracket except via the sink's output bytes.
