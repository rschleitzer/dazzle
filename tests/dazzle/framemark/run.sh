#!/usr/bin/env bash
# tests/dazzle/framemark/run.sh — the frame-mark gate, INVERTED since 2026-08-07.
#
#   tests/dazzle/framemark/run.sh [scalyc-binary]
#
# The mark (packages/dazzle/0.1.0/dazzle/FrameMark.scaly) reclaims per VM FRAME
# inside an eval bracket, and it is ON BY DEFAULT since 2026-08-07 — so every
# other suite in the tree now runs it, and this gate no longer has to. What it
# guards instead is the other three things a default needs:
#
#   1. the mark actually ENGAGES by default (a silently disabled mark passes
#      every differential there is — the same trap the instrument fell into when
#      89 % of frames left through a path it was not watching);
#   2. BOTH escape hatches really turn it off — `DAZZLE_FRAME_MARK=0` and the
#      CLI's `--no-frame-mark`. They are load-bearing: condition 5's
#      completeness is empirically gated rather than proven (see the header of
#      FrameMark.scaly), so the way out has to work on the day it is needed;
#   3. the OFF path still produces the goldens. That path is now the unusual
#      one, and an unusual path with no gate rots.
#
# Numbers and the reasoning behind the six conditions are in
# tests/dazzle/PERFORMANCE.md ("Die Marke GEBAUT", "Die Marke IN PRODUKTION",
# "Die Marke als VORGABE").
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
rc=0

TMP="$(mktemp -d)"
DZ="$TMP/dazzle"
if ! tests/dazzle/build-cli.sh "$DZ" "$BIN" > "$TMP/build.log" 2>&1; then
  echo "framemark: FAIL (build)"; tail -8 "$TMP/build.log"; rm -rf "$TMP"; exit 1
fi

# The mkp codegen writes its `file` flow objects relative to the WORKING
# DIRECTORY, so it runs in a scratch directory with the output tree's shape —
# never in the tree. It used to run in the tree ("byte-identical, nothing to
# restore"), and in tools/bar.sh this suite runs beside every other lane: the
# Intel-Mac bar of 2026-09-27 found dazzle-codegen diffing a parser.scaly this
# suite had just truncated, and anything compiling packages/scalyc meanwhile
# read the same half-written files. (★NEVER restore with `git checkout -- .`
# either: an earlier draft did, and reverted every uncommitted change.)
GEN="$TMP/gen"
mkdir -p "$GEN/packages/scalyc/0.1.0/scalyc/compiler" "$GEN/packages/scalyls/0.1.0/scalyls" \
  "$GEN/editors/vscode/syntaxes"

# --- 1. the mark engages BY DEFAULT --------------------------------------
( cd "$GEN" && SCALY_HOME="$ROOT" "$DZ" --frame-mark-stats \
  -t sgml -d "$ROOT/codegen/scaly.dsl" "$ROOT/scaly.sgm" ) > /dev/null 2> "$TMP/on"
REWOUND="$(sed -n 's/^frame-mark: \([0-9]*\) rewound.*/\1/p' "$TMP/on")"
if [ -z "$REWOUND" ]; then
  echo "framemark: FAIL (no --frame-mark-stats line)"
  cat "$TMP/on"; rc=1
elif [ "$REWOUND" -lt 100 ]; then
  echo "framemark: FAIL (the mark engaged $REWOUND times by default)"; rc=1
else
  echo "framemark: on by default ($REWOUND frames rewound on the mkp codegen)"
fi

# --- 2. both escape hatches turn it OFF ----------------------------------
for way in env cli; do
  if [ "$way" = env ]; then
    ( cd "$GEN" && DAZZLE_FRAME_MARK=0 SCALY_HOME="$ROOT" "$DZ" --frame-mark-stats \
      -t sgml -d "$ROOT/codegen/scaly.dsl" "$ROOT/scaly.sgm" ) > /dev/null 2> "$TMP/off.$way"
  else
    ( cd "$GEN" && SCALY_HOME="$ROOT" "$DZ" --frame-mark-stats --no-frame-mark \
      -t sgml -d "$ROOT/codegen/scaly.dsl" "$ROOT/scaly.sgm" ) > /dev/null 2> "$TMP/off.$way"
  fi
  if [ "$(sed -n 's/^frame-mark: \([0-9]*\) rewound.*/\1/p' "$TMP/off.$way")" != 0 ]; then
    echo "framemark: FAIL (the $way escape hatch did not turn the mark off)"
    head -3 "$TMP/off.$way"; rc=1
  else
    echo "framemark: $way escape hatch turns it off"
  fi
done

# --- 3. the OFF path still makes the goldens ------------------------------
echo "framemark: engine suites with the mark OFF"
if ! DAZZLE_FRAME_MARK=0 tests/dazzle/run.sh "$BIN" > /tmp/framemark-suites.log 2>&1; then
  echo "framemark: FAIL (tests/dazzle/run.sh with the mark off)"; tail -20 /tmp/framemark-suites.log; rc=1
fi

echo "framemark: codegen reproduction with the mark OFF"
if ! DAZZLE_FRAME_MARK=0 tests/dazzle/codegen/run.sh "$BIN" > /tmp/framemark-codegen.log 2>&1; then
  echo "framemark: FAIL (tests/dazzle/codegen/run.sh with the mark off)"; tail -20 /tmp/framemark-codegen.log; rc=1
fi

rm -rf "$TMP"
[ $rc = 0 ] && echo "framemark: PASS" || echo "framemark: FAIL"
exit $rc
