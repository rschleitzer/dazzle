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
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
. tests/toolchain.sh "${1:-}" || exit 2
rc=0

TMP="$(mktemp -d)"
DZ="$TMP/dazzle"
if ! tests/dazzle/build-cli.sh "$DZ" > "$TMP/build.log" 2>&1; then
  echo "framemark: FAIL (build)"; tail -8 "$TMP/build.log"; rm -rf "$TMP"; exit 1
fi

# THE WORKLOAD is a code generator: spec/scaly.dsl (a DSSSL style sheet of
# eight external .scm entities) over the Scaly grammar, which writes a parser,
# a syntax tree and an editor grammar -- 197 KB in five files, 3 680 frames
# rewound. Both inputs are FROZEN FIXTURES: spec/ is a copy of the Scaly
# compiler's codegen/ directory and the document is the SGML corpus's own
# frozen copy of its grammar (tests/sgml/corpus/scaly/), both taken 2026-10-05
# when these suites moved out of that tree. expected.cksum is `cksum` over what
# the C++ reference (dazzle 1.3.3) writes from the same two inputs.
# (In the compiler's tree this gate ran the live generator and compared with
# the generated files committed there; nothing here regenerates anything, the
# five files are only what the engine is measured by.)
#
# The style sheet writes its `file` flow objects relative to the WORKING
# DIRECTORY, so every run gets a scratch directory with the output tree's
# shape -- never the tree.
SPEC="$HERE/spec/scaly.dsl"
DOC="$ROOT/tests/sgml/corpus/scaly/scaly.sgm"
generate() { # generate <label> [env assignments / engine flags via GEN_ENV, GEN_FLAGS]
  local g="$TMP/gen.$1"
  mkdir -p "$g/packages/scalyc/0.1.0/scalyc/compiler" "$g/packages/scalyls/0.1.0/scalyls" \
    "$g/editors/vscode/syntaxes"
  ( cd "$g" && env SCALY_HOME="$ROOT" ${GEN_ENV:-} "$DZ" --frame-mark-stats ${GEN_FLAGS:-} \
    -t sgml -d "$SPEC" "$DOC" ) > /dev/null 2> "$TMP/$1"
}
golden() { # golden <label>: the generated tree against expected.cksum
  ( cd "$TMP/gen.$1" && find . -type f | sed 's|^\./||' | LC_ALL=C sort | xargs cksum ) > "$TMP/$1.cksum"
  cmp -s "$TMP/$1.cksum" "$HERE/expected.cksum"
}
rewound() { sed -n 's/^frame-mark: \([0-9]*\) rewound.*/\1/p' "$TMP/$1"; }

# --- 1. the mark engages BY DEFAULT --------------------------------------
generate on
REWOUND="$(rewound on)"
if [ -z "$REWOUND" ]; then
  echo "framemark: FAIL (no --frame-mark-stats line)"
  cat "$TMP/on"; rc=1
elif [ "$REWOUND" -lt 100 ]; then
  echo "framemark: FAIL (the mark engaged $REWOUND times by default)"; rc=1
else
  echo "framemark: on by default ($REWOUND frames rewound on the code generator)"
fi
if ! golden on; then
  echo "framemark: FAIL (the generated files differ from the reference's with the mark ON)"
  diff "$HERE/expected.cksum" "$TMP/on.cksum" | head -10; rc=1
fi

# --- 2. both escape hatches turn it OFF ----------------------------------
for way in env cli; do
  if [ "$way" = env ]; then
    GEN_ENV="DAZZLE_FRAME_MARK=0" GEN_FLAGS="" generate "off.$way"
  else
    GEN_ENV="" GEN_FLAGS="--no-frame-mark" generate "off.$way"
  fi
  if [ "$(rewound "off.$way")" != 0 ]; then
    echo "framemark: FAIL (the $way escape hatch did not turn the mark off)"
    head -3 "$TMP/off.$way"; rc=1
  else
    echo "framemark: $way escape hatch turns it off"
  fi
done

# --- 3. the OFF path still makes the goldens ------------------------------
echo "framemark: engine self-tests with the mark OFF"
if ! DAZZLE_FRAME_MARK=0 tests/dazzle/run.sh > "$TMP/suites.log" 2>&1; then
  echo "framemark: FAIL (tests/dazzle/run.sh with the mark off)"; tail -20 "$TMP/suites.log"; rc=1
fi

echo "framemark: the code generator with the mark OFF"
for way in env cli; do
  if ! golden "off.$way"; then
    echo "framemark: FAIL (the generated files differ from the reference's with the mark off, $way)"
    diff "$HERE/expected.cksum" "$TMP/off.$way.cksum" | head -10; rc=1
  fi
done

rm -rf "$TMP"
[ $rc = 0 ] && echo "framemark: PASS" || echo "framemark: FAIL"
exit $rc
