#!/usr/bin/env bash
# tests/dazzle/escape/run.sh — the escape-analysis gate.
#
#   tests/dazzle/escape/run.sh [scalyc-binary]
#
# The analysis (packages/dazzle/0.1.0/dazzle/Escape.scaly, DAZZLE_ESCAPE=1) is a
# COMPILE-TIME pass over the Insn graph: it decides, per allocation site, whether
# the value can outlive the frame that produced it. Nothing places anything on
# its verdicts yet, so on its own it changes no output — which is exactly why it
# needs a gate. Two things are checked, and the second is the one that matters:
#
#   1. the engine suites and the codegen reproduction still produce byte-identical
#      output with the analysis on (it must stay observationally neutral), and
#   2. ★DAZZLE_ESCAPE_VERIFY=1 checks the pass's DEPTH MODEL against the running
#      interpreter, insn by insn — `sp - frame_start` as modelled against the real
#      thing. A wrong depth misaligns every slot in a body and would mislabel
#      sites SILENTLY, which is the one mistake in there that no amount of reading
#      the arm twice catches. Measured on the heaviest real-world codegen:
#      739 552 625 checks, 0 wrong.
#
# Plus the analysis must actually have RUN: a build where the pass silently
# turns itself off (the audit table empty because a module moved, a container
# global read before setup) passes every differential above. See
# tests/dazzle/PERFORMANCE.md, "Die Escape-Analyse".
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
rc=0

# NOTE: DAZZLE_ESCAPE_STATS is deliberately NOT set for the differential runs —
# it reports on STDERR, and the byte gates diff stderr against their goldens. The
# frame-mark gate lost a whole run to exactly that.
echo "escape: engine suites with the analysis ON and the depth model verified"
if ! DAZZLE_ESCAPE=1 DAZZLE_ESCAPE_VERIFY=1 tests/dazzle/run.sh "$BIN" > /tmp/escape-suites.log 2>&1; then
  echo "escape: FAIL (tests/dazzle/run.sh)"; tail -20 /tmp/escape-suites.log; rc=1
fi
if grep -q 'DEPTH MODEL WRONG' /tmp/escape-suites.log; then
  echo "escape: FAIL (the depth model disagrees with the interpreter)"
  grep 'DEPTH MODEL WRONG' /tmp/escape-suites.log | head -5; rc=1
fi

echo "escape: codegen reproduction with the analysis ON"
if ! DAZZLE_ESCAPE=1 DAZZLE_ESCAPE_VERIFY=1 tests/dazzle/codegen/run.sh "$BIN" > /tmp/escape-codegen.log 2>&1; then
  echo "escape: FAIL (tests/dazzle/codegen/run.sh)"; tail -20 /tmp/escape-codegen.log; rc=1
fi
if grep -q 'DEPTH MODEL WRONG' /tmp/escape-codegen.log; then
  echo "escape: FAIL (the depth model disagrees with the interpreter)"
  grep 'DEPTH MODEL WRONG' /tmp/escape-codegen.log | head -5; rc=1
fi

# ★And it has to have DONE something. `analysed` counts bodies that made it
# through the abstract interpretation; a pass that turned itself off reports 0
# and would otherwise sail through both differentials above.
TMP="$(mktemp -d)"
DZ="$TMP/dazzle"
if ! tests/dazzle/build-cli.sh "$DZ" "$BIN" > "$TMP/build.log" 2>&1; then
  echo "escape: FAIL (build)"; tail -8 "$TMP/build.log"; rm -rf "$TMP"; exit 1
fi
# ★ NEVER restore with `git checkout -- .` here — see the frame-mark gate.
DAZZLE_ESCAPE=1 DAZZLE_ESCAPE_STATS=1 DAZZLE_ESCAPE_VERIFY=1 "$DZ" \
  --interp -t sgml -d codegen/scaly.dsl scaly.sgm > /dev/null 2> "$TMP/stats"
BODIES="$(sed -n 's/^escape: [0-9]* roots, [0-9]* bodies (\([0-9]*\) analysed).*/\1/p' "$TMP/stats")"
CHECKS="$(sed -n 's/^escape: page-crossed [0-9]*, depth checks \([0-9]*\) .*/\1/p' "$TMP/stats")"
WRONG="$(sed -n 's/^escape: page-crossed [0-9]*, depth checks [0-9]* (\([0-9]*\) wrong).*/\1/p' "$TMP/stats")"
if [ -z "$BODIES" ]; then
  echo "escape: FAIL (no stats line — the pass did not report)"; cat "$TMP/stats"; rc=1
elif [ "$BODIES" -lt 20 ]; then
  echo "escape: FAIL (only $BODIES bodies analysed — the pass is not doing anything)"; rc=1
elif [ -z "$CHECKS" ] || [ "$CHECKS" -lt 1000 ]; then
  echo "escape: FAIL (only ${CHECKS:-0} depth checks — the verifier is not running)"; rc=1
elif [ "${WRONG:-1}" != "0" ]; then
  echo "escape: FAIL ($WRONG depth checks disagreed with the interpreter)"; rc=1
else
  echo "escape: engaged ($BODIES bodies analysed, $CHECKS depth checks, 0 wrong)"
fi
rm -rf "$TMP"

[ $rc = 0 ] && echo "escape: PASS" || echo "escape: FAIL"
exit $rc
