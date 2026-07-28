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
# make-location anchor). toy3/toy4: simple-page-sequence — the six
# header/footer sosofo NICs with the four-page-type dedup (front=/first=
# attributes), page-number-sosofo / current-node-page-number-sosofo, and
# external-procedure (Clark if-first-page / if-front-page + unknown-id -> #f);
# bad2: non-sosofo header/footer values (value-location anchor, process-time
# order after the compile-time keyword message) + left-header: on paragraph.
# toy5/toy6: lazy IC values (VarInheritedC) — inherited-* over initial values,
# pushed specs and nested levels, display-var capture (let-bound var in an IC
# expr), a lazy (style ...) via use:, dimensioned arithmetic on characteristic
# values, actual-* with the depending re-push at a deeper level (toy6's
# display-group re-evaluates the outer font-size) and the circular-use error;
# bad3: inherited-* outside a characteristic value (rule falls back to default
# processing) + the actual-* circularity loop (one message per <p>).
# toy7 (tdoc.sgml): the table family — table/table-part/table-column/table-row/
# table-cell/table-border, table-width (explicit/#f-minimum), the four table
# border NICs with the table-border IC fallback, per-cell cell-*-border
# actuals, column/row styles wrapped in <sequence> (always-attached make
# styles), column-number/n-columns-spanned/n-rows-spanned spans with the
# covered-rowspan fill (synthesized cells incl. the trailing missing dummy),
# starts-row? cells without row FOs (tokenized-attribute pattern match), and
# the table-part principal/header/footer serial decomposition.
# bad4 (tdoc.sgml): constant table NIC errors at COMPILE (value-anchored,
# once: bad border value, column-number 0), table-row/table-cell outside a
# table (location-less, per occurrence, unclosed <table-row> quirk), and a
# non-constant invalid n-rows-spanned (per-process, value-anchored).

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
cp "$HERE"/*.sgml "$HERE"/*.dsl "$HERE"/*.scm "$WORK/"

run_case() { # name expected [expected_err] [document]
  local name="$1" expected="$2" experr="${3:-}" doc="${4:-doc.sgml}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
      "$OUT" -t fot -o "$name.out.fot" -d "$name.dsl" "$doc" 2> "$name.err" )
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
run_case toy3 "$HERE/toy3.expected"
run_case toy4 "$HERE/toy4.expected"
run_case toy5 "$HERE/toy5.expected"
run_case toy6 "$HERE/toy6.expected" "$HERE/toy6.expected.err"
run_case toy7 "$HERE/toy7.expected" "" tdoc.sgml
run_case toy8 "$HERE/toy8.expected" "" tdoc.sgml
run_case bad  "$HERE/bad.expected" "$HERE/bad.expected.err"
run_case bad2 "$HERE/bad2.expected" "$HERE/bad2.expected.err"
run_case bad3 "$HERE/bad3.expected" "$HERE/bad3.expected.err"
run_case bad4 "$HERE/bad4.expected" "$HERE/bad4.expected.err" tdoc.sgml
run_case bad5 "$HERE/bad5.expected" "$HERE/bad5.expected.err" tdoc.sgml

# default output name: <docbase>.fot in the current directory (JadeApp).
( cd "$WORK" && rm -f doc.fot && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
    "$OUT" -t fot -d toy1.dsl doc.sgml 2> /dev/null )
if ! diff -q "$HERE/toy1.expected" "$WORK/doc.fot" > /dev/null; then
  echo "dazzle-fot: FAIL default-output-name"; exit 1
fi

echo "dazzle-fot: PASS"
