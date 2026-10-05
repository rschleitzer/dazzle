# tests/sgml — the dazzle/OpenSP corpus oracle

The survival gate for the OpenSP port. Replays a
frozen corpus of SGML/XML documents against a configurable onsgmls-compatible
binary and diffs ESIS output + exit code against golden snapshots taken from
the reference `onsgmls`. `run.sh` prints the running counter

    N of M models ESIS-identical

which gates every stage. Run against the reference `onsgmls` it reports M/M
(proving the harness and goldens agree); run against the Scaly `onsgmls`
drop-in it reports the coverage achieved so far.

## Two tiers

The corpus is split by **origin**, not by size:

- **`corpus/` — committed, public.** The Scaly compiler's own SGML — its
  grammar `scaly.sgm` and its four literate test suites, real minimization
  stress cases, kept here as FROZEN copies inside the entries `scaly` and
  `expressions` since the corpus moved out of that project's tree
  (2026-10-05) — and hand-written synthetic SGML fixtures (`synth-*`) exercising
  SGML-only features — omitted tags, unquoted attributes, marked sections,
  entities — that a plain XML parser would miss. No external, no local
  content. A fresh checkout runs exactly these.

- **`corpus-private/` — gitignored, local-only.** The full real-world survival
  corpus: further documents plus bulky external standards, each
  parsed in its HOME repo (the manifest carries an absolute `WORKDIR`; nothing
  is copied here). The map that names those repos is itself local and
  lives at `corpus-private/corpus.map` — also gitignored. **Nothing under
  `corpus-private/` is ever committed — not a model, not a golden, not a
  name.**

Rule of thumb: *committed = born in this repo or synthetic; gitignored =
anything pulled from another repo.*

## Running

    tests/sgml/run.sh                     # replay all present tiers (default binary: onsgmls)
    tests/sgml/run.sh --filter 'synth-*'  # only matching entries
    tests/sgml/run.sh /path/to/scaly-onsgmls   # against the port
    tests/sgml/run.sh --bless [binary]    # (re)generate goldens for corpus/ from a binary

A fresh checkout only has `corpus/`; `run.sh` simply reports the
public count. To light up the full gate locally, populate the private tier.

### The discovery gate

`run.sh` also checks HOW MANY models it found, against `expected-models`
(committed for the public tier, written by `fetch-private.sh`/`freeze-private.sh`
for the private one), and fails on **any** difference — fewer *or* more. Growing
the corpus therefore means editing that file, deliberately, in the same commit.

The reason is a failure this suite could not previously report: `N of M
ESIS-identical` says nothing about `M`. A renamed directory, a manifest that lost
its `DOC`, an unfetched private tier — and the run prints `366 of 366` with exit 0
while a hundred models have silently stopped running. The counterpart failure is
just as quiet: on 2026-08-05 the port broke seven models and the number 469/469
kept being quoted from memory (nine places) while the suite
was reporting 462 and exiting 1. Whoever cites a corpus run as a gate cites the
number the run PRINTED.

`--filter` skips the gate — a filtered run is a selection, not a corpus.

## Bootstrapping the private tier

    cp tests/sgml/corpus.map.example tests/sgml/corpus-private/corpus.map
    $EDITOR tests/sgml/corpus-private/corpus.map   # fill in your real repo paths
    tests/sgml/fetch-private.sh [repos-root]       # default root: ~/repos

`fetch-private.sh` is a generic driver: it reads the (gitignored) map, and for
each entry writes a manifest + a golden ESIS blessed from the reference
`onsgmls`. Missing home repos are skipped, so any subset of the real-world
repos being checked out works. Re-run it whenever the sibling repos or the
reference `onsgmls` change.

## Notes

- **Exit codes are part of the oracle.** Several documents exit
  non-zero under `onsgmls` (validation diagnostics, or fragments parsed outside
  their including document). The gate reproduces `onsgmls` *exactly* — its
  errors and exit codes included — so a matching exit 1 is a pass, not a
  failure. The glob tier deliberately over-includes non-root fragments as bonus
  error-path coverage; trim the map if you want only the top-level job docs.
- **Manifest format** (each entry dir has one; sourced by `run.sh`):
  `DOC` (required), `BASE=repo|entry`, `WORKDIR=<abs>` (overrides BASE),
  `SP_ENV="K=V …"`, `EXTRA_ARGS="…"`. See `run.sh` header for details.
- ESIS is path-free, so byte-identity across machines holds; `stderr` is
  captured (`expected.err`) for the Stage-5 stderr-shape work but not gated at
  Stage 0.
