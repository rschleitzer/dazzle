#!/usr/bin/env bash
# tests/dazzle/memhw.sh — Stage-6a-exit memory high-water measurement.
#
#   tests/dazzle/memhw.sh [scalyc-binary]
#
# Measures peak resident set size of the dazzle CLI over the in-repo mkp DSSSL
# codegen corpus (the same five `openjade -G -t sgml -d <spec> <doc>` runs
# tests/dazzle/codegen/run.sh proves byte-identical), alongside openjade on the
# same inputs as the GC baseline. Answers risk-register item 1 (ROADMAP-dazzle):
# does the arena-per-run model retain enough style-eval garbage to need the
# scratch-region or Collector rung? Records numbers, restores the regenerated
# goldens, and leaves the tree clean. Output is RSS figures only — no corpus
# content — so it is safe to run over local corpora too.
#
# macOS: `/usr/bin/time -l` (max RSS in bytes). Linux: `/usr/bin/time -v`
# (max RSS in KB). openjade is optional; skipped with a note if absent.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u
# SCALY_HOME is set only on the CLI *runs* (so packages/dsssl resolves) — never
# on the build below, where it would redirect the runtime archive to lib/.

DZ="$(mktemp -d)/dazzle"
SNAP="$(mktemp -d)"
trap 'rm -rf "$(dirname "$DZ")" "$SNAP"' EXIT

if ! tests/dazzle/build-cli.sh "$DZ" "$BIN" > "$SNAP/build.log" 2>&1; then
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

peak=0
run() {
  local spec="$1" doc="$2"
  local dz oj
  dz=$(peak_rss env SCALY_HOME="$ROOT" "$DZ" -t sgml -d "$spec" "$doc")
  if [ "$have_oj" = 1 ]; then
    oj=$(peak_rss openjade -G -t sgml -d "$spec" "$doc")
  else
    oj=0
  fi
  git checkout -- . >/dev/null 2>&1
  [ "$dz" -gt "$peak" ] && peak="$dz"
  local ojs="n/a" ratio="n/a"
  if [ "$oj" -gt 0 ]; then ojs="$(mb "$oj") MB"; ratio="$(awk -v d="$dz" -v o="$oj" 'BEGIN{printf "%.1fx", d/o}')"; fi
  printf "%-22s %7s MB %10s %8s\n" "$(basename "$spec")" "$(mb "$dz")" "$ojs" "$ratio"
}

run codegen/scaly.dsl            scaly.sgm
run codegen/test-expressions.dsl tests/expressions.sgm
run codegen/test-definitions.dsl tests/definitions.sgm
run codegen/test-choose.dsl      tests/choose.sgm
run codegen/test-controlflow.dsl tests/controlflow.sgm

git checkout -- . >/dev/null 2>&1
echo
echo "dazzle high-water over the mkp DSSSL codegen corpus: $(mb "$peak") MB"
[ "$have_oj" = 0 ] && echo "(openjade not on PATH — baseline columns skipped)"
