#!/usr/bin/env bash
# tests/dazzle/framemark/run.sh — the frame-mark gate.
#
#   tests/dazzle/framemark/run.sh [scalyc-binary]
#
# The mark (packages/dazzle/0.1.0/dazzle/FrameMark.scaly, DAZZLE_FRAME_MARK=1)
# reclaims per VM FRAME inside an eval bracket. It is OFF by default, so without
# a gate it would rot: this runs the two harnesses that cover the engine end to
# end WITH it on, against the very same goldens, and then proves the mark
# actually engaged — a silently disabled mark must not pass a differential.
#
# Numbers and the reasoning behind the five conditions are in
# tests/dazzle/PERFORMANCE.md ("Die Marke GEBAUT", "Die Marke IN PRODUKTION").
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
rc=0

echo "framemark: engine suites with the mark ON"
if ! DAZZLE_FRAME_MARK=1 tests/dazzle/run.sh "$BIN" > /tmp/framemark-suites.log 2>&1; then
  echo "framemark: FAIL (tests/dazzle/run.sh with the mark on)"; tail -20 /tmp/framemark-suites.log; rc=1
fi

echo "framemark: codegen reproduction with the mark ON"
if ! DAZZLE_FRAME_MARK=1 tests/dazzle/codegen/run.sh "$BIN" > /tmp/framemark-codegen.log 2>&1; then
  echo "framemark: FAIL (tests/dazzle/codegen/run.sh with the mark on)"; tail -20 /tmp/framemark-codegen.log; rc=1
fi

# The mark must have DONE something. Without this a build that silently never
# rewinds passes every differential above — the same trap the instrument fell
# into when 89 % of frames left through a path it was not watching.
TMP="$(mktemp -d)"
DZ="$TMP/dazzle"
if ! tests/dazzle/build-cli.sh "$DZ" "$BIN" > "$TMP/build.log" 2>&1; then
  echo "framemark: FAIL (build)"; tail -8 "$TMP/build.log"; rm -rf "$TMP"; exit 1
fi
# ★ NEVER restore with `git checkout -- .` here. An earlier draft did, and it
# reverted every uncommitted source change in the tree. The codegen regenerates
# its outputs byte-identically, so there is nothing to restore in the first place.
DAZZLE_FRAME_MARK=1 DAZZLE_FRAME_MARK_STATS=1 "$DZ" \
  -t sgml -d codegen/scaly.dsl scaly.sgm > /dev/null 2> "$TMP/stats"
REWOUND="$(sed -n 's/^frame-mark: [0-9]* frames, \([0-9]*\) rewound.*/\1/p' "$TMP/stats")"
if [ -z "$REWOUND" ]; then
  echo "framemark: FAIL (no stats line — DAZZLE_FRAME_MARK_STATS did not report)"
  cat "$TMP/stats"; rc=1
elif [ "$REWOUND" -lt 100 ]; then
  echo "framemark: FAIL (the mark engaged $REWOUND times — it is not doing anything)"; rc=1
else
  echo "framemark: engaged ($REWOUND frames rewound on the mkp codegen)"
fi
rm -rf "$TMP"

[ $rc = 0 ] && echo "framemark: PASS" || echo "framemark: FAIL"
exit $rc
