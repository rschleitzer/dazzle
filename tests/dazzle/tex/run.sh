#!/usr/bin/env bash
# tests/dazzle/tex/run.sh — the `-t tex` backend suite (TeXFOTBuilder).
#
#   tests/dazzle/tex/run.sh [scalyc-binary]
#
# Builds the CLI and runs it with -t tex over the fot suite's fixture
# documents and stylesheets (shared from ../fot), byte-diffing the TeX macro
# stream and the argv0-normalized stderr against goldens produced by the
# reference C++ dazzle (/usr/local/bin/dazzle, openjade 1.3.3-pre1) —
# reference-validated 2026-07-30.
#
# Coverage rides the fot toys: the group/atomic macro shapes, the \def
# characteristic stream (float %g lengths + \p@, LengthSpec Factor defs,
# symbol names, Letter2 NUL pairs, DisplaySpace member suffixes), the
# HeadPar/\HeadingText outline machinery, the \SpS*Header/Footer 24-part
# bracket, \Character{N} for chars above 255, the TeX escapes (\char, \/
# ligature breaks, dropped LFs) and the whole table pipeline (\TeXTable
# preamble with per-column alignment/margins, \TeXTableCell overrides,
# \Hline/\Cline vertical border runs, row-span fillers, cell background
# colours).
#
# THREE fixtures are goldens of OUR behaviour because the reference DIES on
# them (documented divergences, verified 2026-07-30):
#   toy9  — content routed through non-principal ports (label:/content-map:)
#           SIGSEGVs the reference TeX backend; our SaveFOTBuilder call queue
#           replays the calls soundly.
#   bad4  — `table-row` outside a table: after the engine's own
#   bad7     "not inside a table" error the reference asserts in curTable()
#           (TeXFOTBuilder.cxx:827) and aborts; we report the invariant
#           through the loud trap (exit 17) at the same point.

HERE="$(cd "$(dirname "$0")" && pwd)"
FOT="$(cd "$HERE/../fot" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
. tests/toolchain.sh "${1:-}" || exit 2
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" > "$OUT.build.log" 2>&1; then
  echo "dazzle-tex: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

cp "$FOT"/*.sgml "$FOT"/*.dsl "$FOT"/*.scm "$WORK/"

run_case() { # name expected [expected_err] [document] [expected_rc]
  local name="$1" expected="$2" experr="${3:-}" doc="${4:-doc.sgml}" exprc="${5:-0}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
      "$OUT" -t tex -o "$name.out.tex" -d "$name.dsl" "$doc" 2> "$name.err" )
  local rc=$?
  if [ "$rc" -ne "$exprc" ]; then
    echo "dazzle-tex: FAIL $name (rc=$rc, expected $exprc)"; cat "$WORK/$name.err"; exit 1
  fi
  if ! diff -q "$expected" "$WORK/$name.out.tex" > /dev/null; then
    echo "dazzle-tex: FAIL $name (tex differs)"
    diff "$expected" "$WORK/$name.out.tex" | head -10
    exit 1
  fi
  if [ -n "$experr" ]; then
    sed 's/^[^:]*:/PROG:/' "$WORK/$name.err" > "$WORK/$name.err.norm"
    if ! diff -q "$experr" "$WORK/$name.err.norm" > /dev/null; then
      echo "dazzle-tex: FAIL $name (stderr differs)"
      diff "$experr" "$WORK/$name.err.norm" | head -10
      exit 1
    fi
  elif [ -s "$WORK/$name.err" ]; then
    echo "dazzle-tex: FAIL $name (unexpected stderr)"; cat "$WORK/$name.err"; exit 1
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
run_case toy9 "$HERE/toy9.expected" "" tdoc.sgml
run_case toy10 "$HERE/toy10.expected" "$HERE/toy10.expected.err"
run_case toy11 "$HERE/toy11.expected"
run_case toy12 "$HERE/toy12.expected"
run_case toy13 "$HERE/toy13.expected"
run_case bad  "$HERE/bad.expected" "$HERE/bad.expected.err"
run_case bad2 "$HERE/bad2.expected" "$HERE/bad2.expected.err"
run_case bad3 "$HERE/bad3.expected" "$HERE/bad3.expected.err"
run_case bad4 "$HERE/bad4.expected" "$HERE/bad4.expected.err" tdoc.sgml 17
run_case bad5 "$HERE/bad5.expected" "$HERE/bad5.expected.err" tdoc.sgml
run_case bad6 "$HERE/bad6.expected" "$HERE/bad6.expected.err"
run_case bad7 "$HERE/bad7.expected" "$HERE/bad7.expected.err" tdoc.sgml 17
run_case bad8 "$HERE/bad8.expected" "$HERE/bad8.expected.err"
run_case bad9 "$HERE/bad9.expected" "$HERE/bad9.expected.err"
run_case bad10 "$HERE/bad10.expected" "$HERE/bad10.expected.err"
run_case bad11 "$HERE/bad11.expected" "$HERE/bad11.expected.err"
run_case bad12 "$HERE/bad12.expected" "$HERE/bad12.expected.err"

# default output name: <docbase>.tex in the current directory (JadeApp).
( cd "$WORK" && rm -f doc.tex && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
    "$OUT" -t tex -d toy1.dsl doc.sgml 2> /dev/null )
if ! diff -q "$HERE/toy1.expected" "$WORK/doc.tex" > /dev/null; then
  echo "dazzle-tex: FAIL default-output-name"; exit 1
fi

echo "dazzle-tex: PASS"
