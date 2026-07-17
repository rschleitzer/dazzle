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

- **The directory flow object does NOT create directories.** A missing output
  directory yields `dazzle:E: cannot open output file "..."` on stderr, the
  content falls through to stdout, and rc STAYS 0. (dazzle-net DIVERGES here —
  its C# `startDirectory` calls `Directory.CreateDirectory`; the C++ binary is
  the oracle, so: no mkdir.)
- `-t sgml` selects the **TransformFOTBuilder** (JadeApp backend switch), not
  SgmlFOTBuilder (that one renders an FOT dump).

## Where the dazzle extension lives

The `directory` flow object is NOT in openjade-net (upstream openjade's
`TransformFOTBuilder.cxx` has no trace); its portable mirror is
`dazzle-net/src/lib/TransformFOTBuilder.cs` (`DirectoryFlowObj`, pubid
`UNREGISTERED::Dazzle//Flow Object Class::directory`, a `directoryStack_`
prefixing entity filenames). **OPEN: the C++ dazzle extension sources are not
checked out locally** — until located, the reference binary is the behavioral
oracle and dazzle-net the structural mirror for this one flow object.

## RBMM mapping

- **One arena region per run** (roadmap doctrine). `Collector.Object` base →
  plain page-hosted structs; Clark's `Collector` interface survives only as
  the allocation seam (objects are `make`d on the run page). No GC in v1;
  the 6a-exit high-water measurement against the 95 MB reference decides
  whether the ladder's scratch-region or Collector rung is needed.
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

- No print path (`InheritedC`, RTF/TeX/MIF/HTML backends) — Stage 9.
- No `call/cc` (loud unsupported error; zero corpus users).
- No JIT — that is 6b, behind the `Expression` seam established here.
- `LangObj`/`MacroFlowObj` etc. ported only if the demand list pulls them in.
