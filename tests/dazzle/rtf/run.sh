#!/usr/bin/env bash
# tests/dazzle/rtf/run.sh — the `-t rtf` backend suite (RtfFOTBuilder, step 3).
#
#   tests/dazzle/rtf/run.sh [scalyc-binary]
#
# Builds the CLI and runs it with -t rtf over the fot suite's fixture
# documents and stylesheets (shared from ../fot), byte-diffing the RTF output
# and the argv0-normalized stderr against goldens produced by the reference
# C++ dazzle (/usr/local/bin/dazzle, openjade 1.3.3-pre1) — reference-
# validated 2026-07-29.
#
# Coverage rides the fot toys: character formatting deltas (sync_char_format),
# the fonttbl in OpenSP HashTable iteration order, paragraph machinery
# (\pard/\sb/\sa/\sl/\fi/\li/keeps/breaks), simple-page-sequence sections with
# the header/footer six-way dedup (\titlepg, \headerl/r/f, \footerl/r/f),
# tables (cell buffering, border store/resolve incl. outside-border
# resolution and vertical spans, \trhdr header rows, \cellx arithmetic),
# line fields (tab stops incl. the align=end trailing-space strip), leaders
# (\tqr\tldot), links/bookmarks (HYPERLINK fields, \bkmkstart insertion
# patching against referenced elements), external-graphic (INCLUDEPICTURE),
# rule (\do drawing objects), score (underline/strikethrough), glyph-subst
# small-caps detection, and the compile/process diagnostics of the bad*
# fixtures (identical stderr shape to the fot suite).
#
# toy9 is EXCLUDED here: it routes content through non-principal ports
# (label:/content-map:), which the byte-level capture seam cannot replay
# into the delta-state RTF stream — the port hard-traps exit 17 by design
# (DESIGN.md "RtfFOTBuilder — design note"; the fix is the SaveFOTBuilder
# call-queue port, deferred until a real document needs it). port_trap
# below pins exactly that behavior so the boundary stays loud.

HERE="$(cd "$(dirname "$0")" && pwd)"
FOT="$(cd "$HERE/../fot" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "dazzle-rtf: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

cp "$FOT"/*.sgml "$FOT"/*.dsl "$FOT"/*.scm "$WORK/"

run_case() { # name expected [expected_err] [document]
  local name="$1" expected="$2" experr="${3:-}" doc="${4:-doc.sgml}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
      "$OUT" -t rtf -o "$name.out.rtf" -d "$name.dsl" "$doc" 2> "$name.err" )
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-rtf: FAIL $name (rc=$rc)"; cat "$WORK/$name.err"; exit 1
  fi
  if ! diff -q "$expected" "$WORK/$name.out.rtf" > /dev/null; then
    echo "dazzle-rtf: FAIL $name (rtf differs)"
    diff "$expected" "$WORK/$name.out.rtf" | head -10
    exit 1
  fi
  if [ -n "$experr" ]; then
    sed 's/^[^:]*:/PROG:/' "$WORK/$name.err" > "$WORK/$name.err.norm"
    if ! diff -q "$experr" "$WORK/$name.err.norm" > /dev/null; then
      echo "dazzle-rtf: FAIL $name (stderr differs)"
      diff "$experr" "$WORK/$name.err.norm" | head -10
      exit 1
    fi
  elif [ -s "$WORK/$name.err" ]; then
    echo "dazzle-rtf: FAIL $name (unexpected stderr)"; cat "$WORK/$name.err"; exit 1
  fi
}

run_case toy1 "$HERE/toy1.expected"
run_case toy2 "$HERE/toy2.expected"
run_case toy3 "$HERE/toy3.expected"
run_case toy4 "$HERE/toy4.expected"
run_case toy5 "$HERE/toy5.expected"
run_case toy6 "$HERE/toy6.expected" "$HERE/toy6.expected.err"
run_case toy7 "$HERE/toy7.expected" "" tdoc.sgml
run_case toy8 "$HERE/toy8.expected" "" tdoc.sgml
run_case toy10 "$HERE/toy10.expected"
run_case toy11 "$HERE/toy11.expected"
run_case toy12 "$HERE/toy12.expected"
run_case toy13 "$HERE/toy13.expected"
run_case bad  "$HERE/bad.expected" "$HERE/bad.expected.err"
run_case bad2 "$HERE/bad2.expected" "$HERE/bad2.expected.err"
run_case bad3 "$HERE/bad3.expected" "$HERE/bad3.expected.err"
run_case bad4 "$HERE/bad4.expected" "$HERE/bad4.expected.err" tdoc.sgml
run_case bad5 "$HERE/bad5.expected" "$HERE/bad5.expected.err" tdoc.sgml
run_case bad6 "$HERE/bad6.expected" "$HERE/bad6.expected.err"
run_case bad7 "$HERE/bad7.expected" "$HERE/bad7.expected.err" tdoc.sgml
run_case bad8 "$HERE/bad8.expected" "$HERE/bad8.expected.err"
run_case bad9 "$HERE/bad9.expected" "$HERE/bad9.expected.err"
run_case bad10 "$HERE/bad10.expected" "$HERE/bad10.expected.err"
run_case bad11 "$HERE/bad11.expected" "$HERE/bad11.expected.err"
run_case bad12 "$HERE/bad12.expected" "$HERE/bad12.expected.err"

# the deferred non-principal-port boundary: toy9 must trap LOUD (exit 17)
( cd "$WORK" && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
    "$OUT" -t rtf -o toy9.out.rtf -d toy9.dsl tdoc.sgml 2> toy9.err )
rc=$?
if [ "$rc" -ne 17 ]; then
  echo "dazzle-rtf: FAIL port-trap (rc=$rc, want 17 — if the SaveFOTBuilder"
  echo "  call-queue landed, promote toy9 to a golden case)"; exit 1
fi
if ! grep -q "non-principal port content is not supported" "$WORK/toy9.err"; then
  echo "dazzle-rtf: FAIL port-trap (message missing)"; cat "$WORK/toy9.err"; exit 1
fi

# default output name: <docbase>.rtf in the current directory (JadeApp).
( cd "$WORK" && rm -f doc.rtf && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
    "$OUT" -t rtf -d toy1.dsl doc.sgml 2> /dev/null )
if ! diff -q "$HERE/toy1.expected" "$WORK/doc.rtf" > /dev/null; then
  echo "dazzle-rtf: FAIL default-output-name"; exit 1
fi

echo "dazzle-rtf: PASS"
