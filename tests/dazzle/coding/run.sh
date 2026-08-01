#!/usr/bin/env bash
# tests/dazzle/coding/run.sh — the OUTPUT CODING SYSTEM suite for the engine:
# every stream a dazzle backend writes, through every encoder the environment
# and `-b` can select, differentially against the reference C++ dazzle.
#
#   tests/dazzle/coding/run.sh [scalyc-binary]
#   tests/dazzle/coding/run.sh --bless [scalyc-binary]   re-mint expected.txt
#
# WHY a matrix and not fixtures: the coding system is chosen by the
# ENVIRONMENT (SP_ENCODING) and by `-b`, so the interesting axis is
# config × backend, and no single fixture exercises more than one cell.
#
# What each axis pins (jade.cxx + CmdLineApp.cxx):
#   - codingSystem() is SP_ENCODING, ALWAYS: a DssslApp is a GroveApp with a
#     required internal charset, so SP_CHARSET_FIXED and SP_BCTF never speak
#     here (the SP_BCTF row proves it — it must read exactly like `default`).
#   - outputCodingSystem_ = `-b` if the name resolves, else codingSystem().
#   - a system of more than ONE byte per char is rejected for the APP coding
#     system (`fixedBytesPerChar() > 1`), so the enc-ucs2 row reads 8-bit —
#     but `-b` is NOT subject to that test, which is why b-unicode writes
#     UTF-16 in every row.
#   - THREE backends write a char stream and therefore encode: fot
#     (jade.cxx:175), the transform sinks for sgml/xml (TransformFOTBuilder
#     :363 stdout and :550 per entity file) and html (HtmlFOTBuilder:448 for
#     the stylesheet, :995 per document file). fot and transform carry
#     outputNumericCharRef as their escaper, so an unencodable char leaves as
#     `&#<decimal>;`; html deliberately sets NONE (`// FIXME setEscaper`,
#     :997) and DROPS it. The `control` rows pin the other half of that
#     statement: rtf, tex and mif write BYTES themselves and must be
#     bit-identical whatever `-b` says.
#   - a BOM belongs to stream CREATION (Encoder::startFile), i.e. to each
#     FILE: the `ent` rows write a second file through an entity flow object
#     and pin that it gets its own FF FE.
#
# DELIBERATE DEVIATION, out of this matrix on purpose: SP_CHARSET_FIXED=YES
# plus SP_ENCODING=UNICODE / UTF-16 (★SP_ENCODING alone does nothing — without
# SP_CHARSET_FIXED the app reads SP_BCTF). Those systems are NOT rejected as the
# app coding system (UnicodeCodingSystem does not override fixedBytesPerChar, so
# it answers the base 0), and the reference then also runs its MESSAGE TABLE and
# its ARGV through them — measured: argv0 comes out truncated, the severity
# letter is gone, `%1` is never substituted, and an odd-byte-length filename
# cannot be opened at all, so the run ends with an empty flow-object tree. Our
# input decoder and output encoder agree with the reference cell for cell there;
# that CmdLineApp string plumbing we deliberately do NOT reproduce (Ralf,
# 2026-08-01: no dependency on a bug). Pinned in tests/sgml/coding/deviation.sh
# with OUR behaviour as the golden; rationale in COMPLETENESS.md.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BLESS=0
if [ "${1:-}" = "--bless" ]; then BLESS=1; shift; fi
BIN="${1:-$ROOT/scalyc/build/scalyc}"
REF="${REF:-/usr/local/bin/dazzle}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if [ "$BLESS" -eq 1 ]; then
  DZ="$REF"
  if [ ! -x "$DZ" ]; then echo "dazzle-coding: no reference at $DZ"; exit 1; fi
else
  if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
    echo "dazzle-coding: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
  fi
  DZ="$OUT"
fi

# the document: ASCII, then a two-byte and a three-byte UTF-8 sequence. An
# 8-bit read sees its BYTES (0x82 is non-SGML, which the golden records), a
# UTF-8 read sees U+00FC and U+20AC.
printf '<!DOCTYPE doc [\n<!ELEMENT doc - - (#PCDATA|em)*>\n<!ELEMENT em - - (#PCDATA)>\n]>\n<doc>a\xc3\xbcb<em>x</em>\xe2\x82\xacc</doc>\n' > "$WORK/d.sgml"
# the same document without the non-ASCII bytes: the entity rows need a run
# that REACHES the flow objects under every configuration (an 8-bit read of
# d.sgml hits a non-SGML character and never opens the document element).
printf '<!DOCTYPE doc [\n<!ELEMENT doc - - (#PCDATA|em)*>\n<!ELEMENT em - - (#PCDATA)>\n]>\n<doc>ab<em>x</em>c</doc>\n' > "$WORK/plain.sgml"
cp "$HERE"/*.dsl "$HERE"/*.scm "$WORK/"

# name|environment
CONFIGS="
default|
enc-utf8|SP_ENCODING=UTF-8
enc-8859-1|SP_ENCODING=ISO-8859-1
enc-koi8|SP_ENCODING=KOI8-R
enc-eucjp|SP_ENCODING=EUC-JP
enc-xml-fixed|SP_CHARSET_FIXED=YES SP_ENCODING=XML
enc-unknown|SP_ENCODING=NO-SUCH-CS
enc-ucs2|SP_ENCODING=UCS-2
bctf-utf8|SP_BCTF=UTF-8
"
# label|-b argument
BEES="
none|
b-utf8|-bUTF-8
b-8859-1|-bISO-8859-1
b-unicode|-bUNICODE
b-eucjp|-bEUC-JP
b-unknown|-bNO-SUCH-CS
"

cell() { # label, then the dazzle arguments
  local label="$1"; shift
  local d="$WORK/run"
  rm -rf "$d"; mkdir -p "$d"
  cp "$WORK/d.sgml" "$WORK/plain.sgml" "$WORK"/*.dsl "$WORK"/*.scm "$d/"
  ( cd "$d" && SCALY_HOME="$ROOT" env -u SP_ENCODING -u SP_BCTF -u SP_CHARSET_FIXED \
      $CELL_ENV "$DZ" "$@" > cell.out 2> cell.err )
  local rc=$?
  {
    printf '=== %s rc=%d\n' "$label" "$rc"
    od -An -c "$d/cell.out"
    printf -- '--- stderr\n'
    # the argv0 prefix differs per binary; everything else is compared raw
    LC_ALL=C sed 's|^[^:]*:|PROG:|' "$d/cell.err" | od -An -c
    # every file the backend wrote itself, in name order
    local f
    for f in $(cd "$d" && ls | LC_ALL=C sort); do
      case "$f" in
        d.sgml|plain.sgml|*.dsl|*.scm|cell.out|cell.err) continue ;;
      esac
      printf -- '--- file %s\n' "$f"
      od -An -c "$d/$f"
    done
  } >> "$MATRIX"
}

MATRIX="$WORK/matrix.txt"
: > "$MATRIX"

while IFS='|' read -r cname cenv; do
  [ -n "$cname" ] || continue
  while IFS='|' read -r bname barg; do
    [ -n "$bname" ] || continue
    CELL_ENV="$cenv"
    for t in fot sgml xml html; do
      if [ -n "$barg" ]; then
        cell "$cname $bname $t" -t $t -d enc.dsl "$barg" -o "out.$t" d.sgml
      else
        cell "$cname $bname $t" -t $t -d enc.dsl -o "out.$t" d.sgml
      fi
    done
  done <<< "$BEES"
done <<< "$CONFIGS"

# controls: the three BYTE backends must not move when the encoder does
for t in rtf tex mif; do
  CELL_ENV=""
  cell "control none $t" -t $t -d enc.dsl -o "out.$t" d.sgml
  cell "control b-unicode $t" -t $t -d enc.dsl -bUNICODE -o "out.$t" d.sgml
  CELL_ENV="SP_ENCODING=KOI8-R"
  cell "control enc-koi8 $t" -t $t -d enc.dsl -o "out.$t" d.sgml
done

# the entity flow object's own file: one stream creation per file, so a
# BOM-writing system stamps it again
for b in "" "-bUNICODE" "-bEUC-JP"; do
  CELL_ENV=""
  if [ -n "$b" ]; then
    cell "entity ${b:-none} sgml" -t sgml -d ent.dsl "$b" plain.sgml
  else
    cell "entity none sgml" -t sgml -d ent.dsl plain.sgml
  fi
done

if [ "$BLESS" -eq 1 ]; then
  cp "$MATRIX" "$HERE/expected.txt"
  echo "dazzle-coding: blessed $(grep -c '^=== ' "$MATRIX") cells from $DZ"
  exit 0
fi

if [ ! -f "$HERE/expected.txt" ]; then
  echo "dazzle-coding: NO GOLDEN (run --bless with the reference dazzle)"; exit 1
fi

if ! diff -q "$HERE/expected.txt" "$MATRIX" > /dev/null; then
  echo "dazzle-coding: FAIL"
  diff "$HERE/expected.txt" "$MATRIX" | head -40
  exit 1
fi
echo "dazzle-coding: PASS ($(grep -c '^=== ' "$MATRIX") cells)"
