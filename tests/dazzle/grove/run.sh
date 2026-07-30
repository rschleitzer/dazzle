#!/usr/bin/env bash
# tests/dazzle/grove/run.sh — the GROVE suite: node classes, axes and node
# properties, differentially against the reference C++ dazzle.
#
#   tests/dazzle/grove/run.sh [scalyc-binary]
#
# Home of the COMPLETENESS.md work-package-1 fixtures (the grove property axis).
# Every golden here is minted from /usr/local/bin/dazzle — these cases cover
# grove semantics that no corpus document exercises, so the reference binary is
# the only oracle.
#
# axis1 (doc.sgml): the DSSSL parent AXIS vs the structural (origin) edge.
# ChunkNode::getParent returns accessNull for every node whose origin is the
# grove root, so `parent`, `ancestor`, `have-ancestor?` and the pattern
# ancestor walk stop at the document ELEMENT, while `origin`, `grove-root`,
# `tree-root` and the sibling axes still see the sgml-document node. The golden
# pins all ten values for the grove root, the document element, a nested title
# and a doubly-nested em.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "dazzle-grove: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

# inputs are COPIED into a scratch workdir (outputs must never land next to the
# repo fixtures).
cp "$HERE"/*.sgml "$HERE"/*.dsl "$HERE"/*.scm "$WORK/"

run_case() { # name expected [expected_err] [document]
  local name="$1" expected="$2" experr="${3:-}" doc="${4:-doc.sgml}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" -t sgml -d "$name.dsl" "$doc" > "$name.out" 2> "$name.err" )
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-grove: FAIL $name (rc=$rc)"; cat "$WORK/$name.err"; exit 1
  fi
  if ! diff -q "$expected" "$WORK/$name.out" > /dev/null; then
    echo "dazzle-grove: FAIL $name (output differs)"
    diff "$expected" "$WORK/$name.out" | head -14
    exit 1
  fi
  if [ -n "$experr" ]; then
    sed 's/^[^:]*:/PROG:/' "$WORK/$name.err" > "$WORK/$name.err.norm"
    if ! diff -q "$experr" "$WORK/$name.err.norm" > /dev/null; then
      echo "dazzle-grove: FAIL $name (stderr differs)"
      diff "$experr" "$WORK/$name.err.norm" | head -10
      exit 1
    fi
  elif [ -s "$WORK/$name.err" ]; then
    echo "dazzle-grove: FAIL $name (unexpected stderr)"; cat "$WORK/$name.err"; exit 1
  fi
}

# chars1 (doc.sgml): per-character grove nodes. The reference's DataNode is a
# (chunk, index) view, so `First <em>inner</em> text.` has 13 children and 18
# descendants; the golden pins the class name (data-char), the leaf shape, the
# `char` property, the one-character `data` of a member against the chunk-wise
# `data` of the whole list, the character-counting follow/preced, (chunk, index)
# identity across two children calls, and that processing such a node-list stays
# CHUNK-WISE (each run emitted once, not once per character).
run_case axis1 "$HERE/axis1.expected"
run_case chars1 "$HERE/chars1.expected"

echo "dazzle-grove: PASS"
