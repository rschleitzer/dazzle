#!/usr/bin/env bash
# tests/sgml/coding/run.sh — the CODING SYSTEM suite: every input decoder and
# output encoder the environment can select, differentially against the
# reference C++ onsgmls.
#
#   tests/sgml/coding/run.sh [binary]        default: /tmp/scaly-onsgmls
#   tests/sgml/coding/run.sh --bless [bin]   re-mint expected.txt from onsgmls
#
# WHY a matrix and not corpus entries: the coding system is chosen by the
# ENVIRONMENT (SP_CHARSET_FIXED / SP_ENCODING / SP_BCTF), so the interesting
# axis is config × document, and no corpus document exercises more than one
# cell. Every cell records stdout, the argv0-normalized stderr and the exit
# status, all concatenated into ONE golden minted from the reference — which is
# the only oracle for these paths.
#
# The documents (built by mkdocs below, so the byte sequences are explicit):
#   u8      valid UTF-8 (ü ß €) — 8-bit reads see its bytes, UTF-8 reads a char
#   emoji   a FOUR-byte UTF-8 sequence: the reference decodes U+FFFD for every
#           sequence of 4+ bytes (charMax < min5-1 in UTF8CodingSystem.cxx)
#   c1      raw 0x80 / 0x9F / 0xA0 — the reference declaration's non-SGML set
#           is 0x80..0x9F and 0xFF, measured byte by byte
#   pi_l1   an XML declaration naming ISO-8859-1 (= the identity system here)
#   pi_u8   an XML declaration naming UTF-8
#   pi_koi  an XML declaration naming KOI8-R (a TranslateCodingSystem)
#   pi_bad  something that only LOOKS like an XML declaration -> the default
#   pi_bogus  an XML declaration naming an unknown encoding -> the default
#   u16be/u16le  a byte-order mark and UTF-16 content
#   pi16be  an XML declaration in UTF-16BE (the 0x003C003F autodetect pattern)
#
# DELIBERATE DEVIATION, out of this matrix on purpose: with SP_CHARSET_FIXED=YES
# (★without it SP_BCTF is read and the names below do nothing) SP_ENCODING=UNICODE
# / UTF-16 make the SYSTEM coding system multi-byte, and the reference then also
# decodes ARGV through it (CmdLineApp::convertInput — the filename becomes
# mojibake and, at odd byte length, cannot be opened at all), pushes its own
# MESSAGE TABLE through it (the getMessageText override — `%1` is never
# substituted) and encodes STDERR through it (makeStdErr). We do NOT reproduce
# that (Ralf, 2026-08-01: no dependency on a bug). Pinned separately in
# ./deviation.sh, whose golden is OUR behaviour.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BLESS=0
if [ "${1:-}" = "--bless" ]; then BLESS=1; shift; fi
BIN="${1:-/tmp/scaly-onsgmls}"
cd "$ROOT"
# shellcheck disable=SC1091
. "$HERE/../../platform.sh" || exit 1
set -u

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdocs() {
  python3 - "$WORK" <<'PY'
import sys, codecs, os
w = sys.argv[1]
doc = '<!DOCTYPE doc [\n<!ELEMENT doc - - (#PCDATA)>\n]>\n<doc>Grüße</doc>\n'
W = lambda n, b: open(os.path.join(w, n), 'wb').write(b)
W('u8.sgml', '<!DOCTYPE doc [\n<!ELEMENT doc - - (#PCDATA)>\n]>\n<doc>Grüße €</doc>\n'.encode('utf-8'))
W('emoji.sgml', b'<!DOCTYPE doc [\n<!ELEMENT doc - - (#PCDATA)>\n]>\n<doc>A\xf0\x9f\x98\x80B</doc>\n')
W('c1.sgml', b'<!DOCTYPE doc [\n<!ELEMENT doc - - (#PCDATA)>\n]>\n<doc>A\x80B\x9fC\xa0D</doc>\n')
W('pi_l1.sgml', b'<?xml version="1.0" encoding="ISO-8859-1"?>\n' + doc.encode('latin-1'))
W('pi_u8.sgml', b'<?xml version="1.0" encoding="UTF-8"?>\n' + doc.encode('utf-8'))
W('pi_koi.sgml', b'<?xml version="1.0" encoding="KOI8-R"?>\n' + doc.encode('latin-1'))
W('pi_bad.sgml', b'<?xmlbad?>\n' + doc.encode('utf-8'))
W('pi_bogus.sgml', b'<?xml version="1.0" encoding="NO-SUCH-CS"?>\n' + doc.encode('utf-8'))
W('u16be.sgml', codecs.BOM_UTF16_BE + doc.encode('utf-16-be'))
W('u16le.sgml', codecs.BOM_UTF16_LE + doc.encode('utf-16-le'))
W('pi16be.sgml', ('<?xml version="1.0" encoding="UTF-16"?>\n' + doc).encode('utf-16-be'))
PY
}

DOCS="u8 emoji c1 pi_l1 pi_u8 pi_koi pi_bad pi_bogus u16be u16le pi16be"
# name|environment
CONFIGS="
default|
enc-utf8-unfixed|SP_ENCODING=utf-8
bctf-utf8|SP_BCTF=UTF-8
bctf-euc|SP_BCTF=EUC
bctf-sjis|SP_BCTF=SJIS
bctf-big5|SP_BCTF=BIG5
bctf-fixed2|SP_BCTF=FIXED-2
bctf-fixed4|SP_BCTF=FIXED-4
bctf-identity|SP_BCTF=IDENTITY
fixed-xml|SP_CHARSET_FIXED=YES SP_ENCODING=XML
fixed-utf8|SP_CHARSET_FIXED=YES SP_ENCODING=UTF-8
fixed-8859-1|SP_CHARSET_FIXED=YES SP_ENCODING=ISO-8859-1
fixed-8859-5|SP_CHARSET_FIXED=YES SP_ENCODING=ISO-8859-5
fixed-koi8|SP_CHARSET_FIXED=YES SP_ENCODING=KOI8-R
fixed-eucjp|SP_CHARSET_FIXED=YES SP_ENCODING=EUC-JP
fixed-euccn|SP_CHARSET_FIXED=YES SP_ENCODING=EUC-CN
fixed-euckr|SP_CHARSET_FIXED=YES SP_ENCODING=EUC-KR
fixed-sjis|SP_CHARSET_FIXED=YES SP_ENCODING=SJIS
fixed-big5|SP_CHARSET_FIXED=YES SP_ENCODING=BIG5
fixed-ucs2|SP_CHARSET_FIXED=YES SP_ENCODING=UCS-2
fixed-unknown|SP_CHARSET_FIXED=YES SP_ENCODING=NO-SUCH-CS
"

mkdocs
OUT="$WORK/matrix.txt"
: > "$OUT"
while IFS='|' read -r name env; do
  [ -n "$name" ] || continue
  for doc in $DOCS; do
    ( cd "$WORK" && env -u SP_ENCODING -u SP_BCTF -u SP_CHARSET_FIXED $env \
        "$BIN" "$doc.sgml" > "cell.out" 2> "cell.err" )
    rc=$?
    {
      printf '=== %s %s rc=%d\n' "$name" "$doc" "$rc"
      # stdout and stderr are BINARY in some cells (UTF-16 output), so both are
      # dumped byte-wise; stderr loses its argv0 prefix first (differs per
      # binary). ★The dump is ./dump.py and NOT `od`, because `od -c` bakes its
      # host into the golden two ways at once — a locale-dependent multibyte
      # rendering AND an implementation-dependent column padding. dump.py has
      # the full account and is checked against GNU od byte for byte.
      python3 "$HERE/dump.py" "$WORK/cell.out"
      printf -- '--- stderr\n'
      sed 's/^[^:]*:/PROG:/' "$WORK/cell.err" | python3 "$HERE/dump.py"
    } >> "$OUT"
  done
done <<< "$CONFIGS"

if [ "$BLESS" -eq 1 ]; then
  cp "$OUT" "$HERE/expected.txt"
  echo "coding: blessed $(grep -c '^=== ' "$OUT") cells from $BIN"
  exit 0
fi

if [ ! -f "$HERE/expected.txt" ]; then
  echo "coding: NO GOLDEN (run --bless with the reference onsgmls)"; exit 1
fi
if diff -q "$HERE/expected.txt" "$OUT" > /dev/null; then
  echo "coding: PASS ($(grep -c '^=== ' "$OUT") cells)"
  exit 0
fi
echo "coding: FAIL"
diff "$HERE/expected.txt" "$OUT" | head -40
exit 1
