#!/usr/bin/env bash
# tests/sgml/run.sh — the dazzle/OpenSP corpus oracle.
#
# Replays the frozen SGML/XML corpus against a configurable onsgmls-compatible
# parser binary and diffs its ESIS output + exit code against the golden
# snapshots taken from the real onsgmls. Prints the running counter
#
#     N of M models ESIS-identical
#
# which is THE progress bar for Part I of the port (Stages 0-5). Run with the
# default binary (onsgmls) it must report M/M — proving the harness and the
# frozen goldens agree with the reference. Run against the Scaly onsgmls
# drop-in it reports the coverage that gates every following stage.
#
# Usage:
#   tests/sgml/run.sh [binary]          replay (default binary: onsgmls)
#   tests/sgml/run.sh --bless [binary]  regenerate goldens from binary (onsgmls)
#   tests/sgml/run.sh --filter <glob>   only entries whose name matches
#
# Two-tier corpus (see README.md):
#   corpus/          public, committed — Scaly's own SGML + synthetic fixtures
#   corpus-private/  gitignored further documents (fetch-private.sh)
#
# ★The count is GATED (see the discovery gate at the bottom): the number of
# models found must equal `expected-models` — the public tier's is committed, the
# private tier's is written by fetch/freeze. A number nobody checks is a number
# that drifts: "469/469" was quoted in PERFORMANCE.md at nine places while the
# suite was reporting 462, and the reverse failure (a tier that silently stops
# being discovered, so M shrinks and N/M still reads "all green") had nothing
# watching it at all. Both directions fail here.
#
# Per-entry layout: a directory with a `manifest` and golden `expected.esis` +
# `expected.exit`. The manifest is sourced and may set:
#   DOC=<file>            document passed to the binary (required)
#   BASE=repo|entry       resolve DOC/cwd against repo root or the entry dir
#                         (default: entry — self-contained fixture)
#   WORKDIR=<path>        cwd override (wins over BASE). ABSOLUTE: the model
#                         stays in its home repo and no local source is
#                         copied into this tree. RELATIVE: resolved against the
#                         entry — a FROZEN private entry (freeze-private.sh)
#                         carrying its own copy, so the corpus stops drifting
#                         when those repos move on
#   SP_ENV="K=V K=V"      environment prefix (e.g. SP_CHARSET_FIXED=YES SP_ENCODING=XML)
#   EXTRA_ARGS="..."      extra args before DOC (e.g. a leading xml.dcl, -c catalog)
#   RAST=1                run with -t <tmpfile> and compare it against the
#                         entry's expected.rast golden (the -t RAST axis)

# ★The loop is tests/sgml/run.py since 2026-10-03: this file is its entry
# point, same arguments, same output, same exit codes (plus --jobs <n>). The
# shell loop forked ~10 processes per model, and on Windows every fork is
# emulated -- 4 min 50 s for the 380 public models there, against 1.7 s for the
# driver starting the native binary itself, in parallel
# (tests/win32/WINDOWS-BOX.md §8). The discovery gate, the stdin check and the
# stderr normalisation are the driver's; their accounts stay in its comments.

HERE="$(cd "$(dirname "$0")" && pwd)"
PY=$(command -v python3 || command -v python) || { echo "tests/sgml/run.sh: no python3" >&2; exit 2; }
exec "$PY" "$HERE/run.py" "$@"
