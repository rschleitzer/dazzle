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
# with OUR behaviour as the golden.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BLESS=0
if [ "${1:-}" = "--bless" ]; then BLESS=1; shift; fi
REF="${REF:-/usr/local/bin/dazzle}"
cd "$ROOT"
# shellcheck disable=SC1091
. tests/toolchain.sh "${1:-}" || exit 2
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if [ "$BLESS" -eq 1 ]; then
  DZ="$REF"
  if [ ! -x "$DZ" ]; then echo "dazzle-coding: no reference at $DZ"; exit 1; fi
else
  if ! tests/dazzle/build-cli.sh "$OUT" > "$OUT.build.log" 2>&1; then
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

# The cells -- the configuration and -b tables, the byte dump and the
# assembly of the matrix -- are tests/dazzle/coding/run.py since 2026-10-03:
# each of the 228 forked some fifteen processes here, and Git Bash emulates every
# fork (320 s on the Windows box, the slowest dazzle suite by six). The driver
# writes the same matrix, byte for byte; the cells run in parallel.
#
# On Windows the native binary beside the front end is run directly: its CR LF
# is gone since the standard streams are binary, and the driver passes a
# program name without a colon (stderr's name is replaced up to the first one).
DZBIN="$DZ"
for c in "$DZ-native.exe" "${DAZZLE_PREBUILT:-/nonexistent}-native.exe"; do
  [ -f "$c" ] && { DZBIN="$c"; break; }
done
MATRIX="$WORK/matrix.txt"
PY=$(command -v python3 || command -v python) || { echo "dazzle-coding: no python3"; exit 1; }
"$PY" "$HERE/run.py" "$DZBIN" "$WORK" "$MATRIX" || { echo "dazzle-coding: FAIL (driver)"; exit 1; }

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
