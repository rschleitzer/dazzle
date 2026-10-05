#!/usr/bin/env bash
# tests/dazzle/mif/run.sh — the `-t mif` backend suite (MifFOTBuilder).
#
#   tests/dazzle/mif/run.sh [scalyc-binary]
#
# Builds the CLI and runs it with -t mif over the fot suite's fixture
# documents and stylesheets (shared from ../fot), byte-diffing the MIF output
# and the argv0-normalized stderr against goldens produced by the reference
# C++ dazzle (/usr/local/bin/dazzle, openjade 1.3.3-pre1) — reference-
# validated 2026-07-30.
#
# Coverage rides the fot toys: the PgfCatalog default format, the delta
# Pgf/PgfFont/Font statements, the T_dimension `%li.%.3i` + zero-strip format,
# T_string escaping and the `\xNN ` Frame-charset codes, the PgfLanguage
# mapping (including the reference's missing `break` after the German arm),
# the whole simple-page-sequence machinery (master/body pages, ten TextRects
# with the global object-ID counter, the seven text flows, header/footer tab
# stops, the 24-part header/footer bracket with its firstHF-only-not-frontHF
# escape into the body flow), leaders and line fields, scores, rules and
# anchored frames (PolyLine/ImportObject/Frame), the whole table pipeline
# (column processing with the `missing table column flow object` warnings the
# reference's TablePart::begin column wipe provokes, border resolution,
# rulings interned in PointerTable slot order, TblH/TblBody/TblF) and the
# two-pass Marker/XRef cross-reference resolution.
#
# THREE fixtures are goldens of OUR behaviour because the reference DIES on
# them (documented divergences, verified 2026-07-30):
#   toy6  — `(* 2 (actual-line-spacing))` leaves the reference with a closed
#           paragraph and it asserts in curPara() (MifFOTBuilder.cxx:1105);
#           our engine reports the circular characteristic value (the same
#           diagnostic the fot and tex suites golden) and carries on.
#   toy8  — same curPara() assert, reached through the colour-space toys.
#   toy9  — content routed through non-principal ports (label:/content-map:)
#           SIGSEGVs the reference MIF backend; our SaveFOTBuilder call queue
#           replays the calls soundly.

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
  echo "dazzle-mif: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

cp "$FOT"/*.sgml "$FOT"/*.dsl "$FOT"/*.scm "$WORK/"

run_case() { # name expected [expected_err] [document] [expected_rc]
  local name="$1" expected="$2" experr="${3:-}" doc="${4:-doc.sgml}" exprc="${5:-0}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
      "$OUT" -t mif -o "$name.out.mif" -d "$name.dsl" "$doc" 2> "$name.err" )
  local rc=$?
  if [ "$rc" -ne "$exprc" ]; then
    echo "dazzle-mif: FAIL $name (rc=$rc, expected $exprc)"; cat "$WORK/$name.err"; exit 1
  fi
  if ! diff -q "$expected" "$WORK/$name.out.mif" > /dev/null; then
    echo "dazzle-mif: FAIL $name (mif differs)"
    diff "$expected" "$WORK/$name.out.mif" | head -10
    exit 1
  fi
  if [ -n "$experr" ]; then
    sed 's/^[^:]*:/PROG:/' "$WORK/$name.err" > "$WORK/$name.err.norm"
    if ! diff -q "$experr" "$WORK/$name.err.norm" > /dev/null; then
      echo "dazzle-mif: FAIL $name (stderr differs)"
      diff "$experr" "$WORK/$name.err.norm" | head -10
      exit 1
    fi
  elif [ -s "$WORK/$name.err" ]; then
    echo "dazzle-mif: FAIL $name (unexpected stderr)"; cat "$WORK/$name.err"; exit 1
  fi
}

run_case toy1 "$HERE/toy1.expected"
run_case toy2 "$HERE/toy2.expected"
run_case toy3 "$HERE/toy3.expected"
run_case toy4 "$HERE/toy4.expected"
run_case toy5 "$HERE/toy5.expected"
run_case toy6 "$HERE/toy6.expected" "$HERE/toy6.expected.err"
run_case toy7 "$HERE/toy7.expected" "$HERE/toy7.expected.err" tdoc.sgml
run_case toy8 "$HERE/toy8.expected" "$HERE/toy8.expected.err" tdoc.sgml
run_case toy9 "$HERE/toy9.expected" "$HERE/toy9.expected.err" tdoc.sgml
run_case toy10 "$HERE/toy10.expected"
run_case toy11 "$HERE/toy11.expected"
run_case toy12 "$HERE/toy12.expected"
run_case toy13 "$HERE/toy13.expected"
run_case bad  "$HERE/bad.expected" "$HERE/bad.expected.err"
run_case bad2 "$HERE/bad2.expected" "$HERE/bad2.expected.err"
run_case bad3 "$HERE/bad3.expected" "$HERE/bad3.expected.err"
run_case bad4 "$HERE/bad4.expected" "$HERE/bad4.expected.err" tdoc.sgml
run_case bad5 "$HERE/bad5.expected" "$HERE/bad5.expected.err"
run_case bad6 "$HERE/bad6.expected" "$HERE/bad6.expected.err"
run_case bad7 "$HERE/bad7.expected" "$HERE/bad7.expected.err" tdoc.sgml
run_case bad8 "$HERE/bad8.expected" "$HERE/bad8.expected.err"
run_case bad9 "$HERE/bad9.expected" "$HERE/bad9.expected.err"
run_case bad10 "$HERE/bad10.expected" "$HERE/bad10.expected.err"
run_case bad11 "$HERE/bad11.expected" "$HERE/bad11.expected.err"
run_case bad12 "$HERE/bad12.expected" "$HERE/bad12.expected.err"

# default output name: <docbase>.mif in the current directory (JadeApp). The
# name reaches the XRef statements, so toy1 (which has none) is the fixture.
( cd "$WORK" && rm -f doc.mif && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
    "$OUT" -t mif -d toy1.dsl doc.sgml 2> /dev/null )
if ! diff -q "$HERE/toy1.expected" "$WORK/doc.mif" > /dev/null; then
  echo "dazzle-mif: FAIL default-output-name"; exit 1
fi

# more than one simple-page-sequence: the root file becomes a <Book 5.0> and
# the components go to 1.mif/2.mif/3.mif next to it (MifDoc::commit).
cp "$HERE/book.dsl" "$HERE/book.scm" "$WORK/"
( cd "$WORK" && rm -f 1.mif 2.mif 3.mif && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
    "$OUT" -t mif -o book.out.mif -d book.dsl doc.sgml 2> book.err )
for f in book.out.mif 1.mif 2.mif 3.mif; do
  if ! diff -q "$HERE/book-$f.expected" "$WORK/$f" > /dev/null; then
    echo "dazzle-mif: FAIL book ($f differs)"
    diff "$HERE/book-$f.expected" "$WORK/$f" | head -10
    exit 1
  fi
done

echo "dazzle-mif: PASS"
