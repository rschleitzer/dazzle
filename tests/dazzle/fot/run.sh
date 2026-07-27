#!/usr/bin/env bash
# tests/dazzle/fot/run.sh — the `-t fot` backend suite (SgmlFOTBuilder, Inc 8).
#
#   tests/dazzle/fot/run.sh [scalyc-binary]
#
# Builds the CLI and runs it with -t fot over fixture documents, byte-diffing
# the flow-object-tree output (and, for the error fixture, the argv0-normalized
# stderr) against goldens produced by the reference C++ dazzle
# (/usr/local/bin/dazzle, openjade 1.3.3-pre1) — reference-validated 2026-07-27.
#
# Covered: sequence/paragraph/paragraph-break/display-group/line-field flow
# objects, DisplayNIC keywords (keep/keeps/breaks/space-before), inherited
# characteristics (length/length-spec/symbol/bool/string/letter2) incl. the
# millipoint Units quirks (.5pt/-3pt), use: chains, (style ...) values,
# pending <a name=…/> element anchors (ID + element index), text escaping
# (&amp;/&lt; + numeric char refs), the default <docbase>.fot output name, and
# the invalid-value / invalid-keyword diagnostics (make vs style message,
# make-location anchor).

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "dazzle-fot: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

# inputs are COPIED into a scratch workdir (sweep-harness lesson: outputs must
# never land next to repo fixtures).
cp "$HERE"/doc.sgml "$HERE"/*.dsl "$HERE"/*.scm "$WORK/"

run_case() { # name expected [expected_err]
  local name="$1" expected="$2" experr="${3:-}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
      "$OUT" -t fot -o "$name.out.fot" -d "$name.dsl" doc.sgml 2> "$name.err" )
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-fot: FAIL $name (rc=$rc)"; cat "$WORK/$name.err"; exit 1
  fi
  if ! diff -q "$expected" "$WORK/$name.out.fot" > /dev/null; then
    echo "dazzle-fot: FAIL $name (fot differs)"
    diff "$expected" "$WORK/$name.out.fot" | head -10
    exit 1
  fi
  if [ -n "$experr" ]; then
    sed 's/^[^:]*:/PROG:/' "$WORK/$name.err" > "$WORK/$name.err.norm"
    if ! diff -q "$experr" "$WORK/$name.err.norm" > /dev/null; then
      echo "dazzle-fot: FAIL $name (stderr differs)"
      diff "$experr" "$WORK/$name.err.norm" | head -10
      exit 1
    fi
  elif [ -s "$WORK/$name.err" ]; then
    echo "dazzle-fot: FAIL $name (unexpected stderr)"; cat "$WORK/$name.err"; exit 1
  fi
}

run_case toy1 "$HERE/toy1.expected"
run_case toy2 "$HERE/toy2.expected"
run_case bad  "$HERE/bad.expected" "$HERE/bad.expected.err"

# default output name: <docbase>.fot in the current directory (JadeApp).
( cd "$WORK" && rm -f doc.fot && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
    "$OUT" -t fot -d toy1.dsl doc.sgml 2> /dev/null )
if ! diff -q "$HERE/toy1.expected" "$WORK/doc.fot" > /dev/null; then
  echo "dazzle-fot: FAIL default-output-name"; exit 1
fi

echo "dazzle-fot: PASS"
