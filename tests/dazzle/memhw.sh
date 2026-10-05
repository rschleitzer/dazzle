#!/usr/bin/env bash
# tests/dazzle/memhw.sh — Stage-6a-exit memory high-water measurement.
#
#   tests/dazzle/memhw.sh [scalyc-binary]
#
# Measures peak resident set size of the dazzle CLI over a DSSSL code
# generator — the Scaly grammar's, frozen as the fixture of
# tests/dazzle/framemark (spec/scaly.dsl over tests/sgml/corpus/scaly/scaly.sgm;
# that suite proves the output byte-identical to the reference's) — alongside
# openjade on the same inputs as the GC baseline. Answers risk-register item 1:
# does the arena-per-run model retain enough style-eval garbage to need the
# scratch-region or Collector rung? Output is RSS figures only — no corpus
# content — so nothing of a document reaches the report.
#
# (In the Scaly compiler's tree, where this lived until 2026-10-05, it ran the
# five generator runs of that project's build; the four literate-test style
# sheets stayed there, the grammar's is the heavy one.)
#
# The style sheet writes its files relative to the WORKING DIRECTORY, so the
# runs happen in a scratch directory with the output tree's shape. (They used
# to happen in the tree, followed by a `git checkout -- .` — which reverts
# every uncommitted change with them.)
#
# macOS: `/usr/bin/time -l` (max RSS in bytes). Linux: `/usr/bin/time -v`
# (max RSS in KB). openjade is optional; skipped with a note if absent.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
. tests/toolchain.sh "${1:-}" || exit 2
set -u
# SCALY_HOME on a CLI *run* is this repository: the engine resolves its DSSSL
# prolog and catalog under <home>/packages/dazzle/0.1.0/dsssl. The build keeps
# whatever the environment says (the compiler's installation).

DZ="$(mktemp -d)/dazzle"
SNAP="$(mktemp -d)"
trap 'rm -rf "$(dirname "$DZ")" "$SNAP"' EXIT

if ! tests/dazzle/build-cli.sh "$DZ" > "$SNAP/build.log" 2>&1; then
  echo "dazzle-memhw: FAIL (build)"; tail -8 "$SNAP/build.log"; exit 1
fi

have_oj=1; command -v openjade >/dev/null 2>&1 || have_oj=0

# peak_rss <cmd...> -> echoes max RSS in bytes (portable macOS/Linux)
peak_rss() {
  /usr/bin/time -l "$@" >/dev/null 2>"$SNAP/t" && :
  local b
  b=$(awk '/maximum resident set size/{print $1; f=1} END{if(!f) print ""}' "$SNAP/t")
  if [ -z "$b" ]; then
    # GNU time (-v): "Maximum resident set size (kbytes): N"
    /usr/bin/time -v "$@" >/dev/null 2>"$SNAP/t"
    b=$(awk -F': ' '/Maximum resident set size/{print $2*1024}' "$SNAP/t")
  fi
  echo "${b:-0}"
}

mb() { awk -v b="$1" 'BEGIN{printf "%.1f", b/1048576}'; }

printf "%-22s %10s %10s %8s\n" "codegen run" "dazzle" "openjade" "ratio"
printf "%-22s %10s %10s %8s\n" "-----------" "------" "--------" "-----"

GEN="$SNAP/gen"
mkdir -p "$GEN/packages/scalyc/0.1.0/scalyc/compiler" "$GEN/packages/scalyls/0.1.0/scalyls" \
  "$GEN/editors/vscode/syntaxes"

peak=0
run() {
  local spec="$ROOT/$1" doc="$ROOT/$2"
  local dz oj
  dz=$(cd "$GEN" && peak_rss env SCALY_HOME="$ROOT" "$DZ" -t sgml -d "$spec" "$doc")
  if [ "$have_oj" = 1 ]; then
    oj=$(cd "$GEN" && peak_rss openjade -G -t sgml -d "$spec" "$doc")
  else
    oj=0
  fi
  [ "$dz" -gt "$peak" ] && peak="$dz"
  local ojs="n/a" ratio="n/a"
  if [ "$oj" -gt 0 ]; then ojs="$(mb "$oj") MB"; ratio="$(awk -v d="$dz" -v o="$oj" 'BEGIN{printf "%.1fx", d/o}')"; fi
  printf "%-22s %7s MB %10s %8s\n" "$(basename "$spec")" "$(mb "$dz")" "$ojs" "$ratio"
}

run tests/dazzle/framemark/spec/scaly.dsl tests/sgml/corpus/scaly/scaly.sgm

echo
echo "dazzle high-water over the frozen code generator: $(mb "$peak") MB"
[ "$have_oj" = 0 ] && echo "(openjade not on PATH — baseline columns skipped)"
exit 0
