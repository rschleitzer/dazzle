#!/usr/bin/env bash
# tests/sgml/coding/deviation.sh — the ONE deliberate behavioural deviation
# from the C++ reference, pinned so it cannot drift silently.
#
#   tests/sgml/coding/deviation.sh [binary]        default: /tmp/scaly-onsgmls
#   tests/sgml/coding/deviation.sh --bless [bin]   re-mint deviation-expected.txt
#
# ★ Unlike every other golden in this tree, deviation-expected.txt is blessed
#   from OUR binary, not from the reference. It records what WE do, on purpose.
#   Decided 2026-08-01 by Ralf: "drop-in replacement" does not oblige us to
#   reproduce broken behaviour — we will not breed a dependency on a bug.
#
# WHAT DEVIATES.  With SP_CHARSET_FIXED=YES the app reads SP_ENCODING (not
# SP_BCTF) as the SYSTEM coding system (CmdLineApp.cxx:511), and only FIXED-2 /
# FIXED-4 are rejected by the fixedBytesPerChar() > 1 gate (:522) — they are the
# only systems that override it. So SP_ENCODING=UNICODE and =UTF-16 become the
# app coding system, and the reference then pushes ASCII through it at three
# sites: convertInput (argv, :549), the getMessageText override (the message
# TABLE — CmdLineApp derives from SP_REPORTER_CLASS, so this overrides
# MessageReporter's plain widening, :457) and makeStdErr (the stderr sink, :566).
# Decoding ASCII as UTF-16 and re-encoding it round-trips, which produces:
#
#   reference, `onsgmls uu.sgm`, SP_CHARSET_FIXED=YES SP_ENCODING=UNICODE:
#     ff fe "onsgml" 00 ':' "uu.sgm" 00 ':' 00 '1' 00 ':' 00 '0' 00 ':' 00 ':'
#            ^ argv0 truncated              ^ no severity letter ^^^^^^^^^
#     00 ' character %1 not allowed in prolog'
#              ^ %1 NEVER substituted
#
#   ours: '/tmp/scaly-onsgmls:uu.sgm:1:0:E: character "..." not allowed in
#          prolog' in clean UTF-16 — argv0 intact, severity present, argument
#          substituted.
#
# WHY THIS IS SAFE TO DEVIATE ON (the criteria, measured 2026-08-01):
#  1. The OUTCOME is identical: both implementations fail, rc 1, and stdout is
#     the 2-byte BOM either way. No caller can distinguish success from success.
#  2. The reference's diagnostic is not a message at all — no severity letter,
#     `%1` unsubstituted, and its bytes are only readable if you decode the
#     stream with the WRONG endianness. Nothing can depend on it.
#  3. It is CLI stream plumbing, not engine semantics, so this cannot mask a
#     porting bug in any working configuration: every ASCII-transparent app
#     coding system (UTF-8, XML, ISO-8859-x, KOI8, Big5, EUC-*, SJIS, identity)
#     makes the decode/encode round trip the IDENTITY, and those are covered
#     byte-for-byte by the 469-entry ESIS corpus plus run.sh's own matrix.
#  4. ★The reference's failure mode depends on the FILENAME'S BYTE-LENGTH
#     PARITY: an odd-length name loses its last byte in the round trip, so the
#     file cannot be opened at all ("cannot open %1 (%2"); an even-length name
#     survives and the document is parsed. That is not behaviour to reproduce.
#
# This script therefore does two things: it pins our output, AND it asserts the
# reference still deviates. If the reference ever agrees with us, the deviation
# is gone and the doctrine decision above should be revisited — the script says
# so loudly instead of passing quietly.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BLESS=0
if [ "${1:-}" = "--bless" ]; then BLESS=1; shift; fi
BIN="${1:-/tmp/scaly-onsgmls}"
cd "$ROOT"
set -u

if ! command -v "$BIN" >/dev/null 2>&1 && [ ! -x "$BIN" ]; then
  echo "deviation: binary not found: $BIN" >&2; exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Two ASCII documents differing ONLY in filename byte-length parity (5 vs 6),
# and two UTF-16LE documents likewise (7 vs 8) — the parity is the point.
python3 - "$WORK" <<'PY'
import codecs, os, sys
w = sys.argv[1]
ascii_doc = '<!DOCTYPE doc [<!ELEMENT doc - - (#PCDATA)>]>\n<doc>x</doc>\n'
u16 = codecs.BOM_UTF16_LE + ascii_doc.encode('utf-16-le')
W = lambda n, b: open(os.path.join(w, n), 'wb').write(b)
W('a.sgm',    ascii_doc.encode())   # 5-byte name  (odd)
W('ab.sgm',   ascii_doc.encode())   # 6-byte name  (even)
W('w16.sgm',  u16)                  # 7-byte name  (odd)
W('w16b.sgm', u16)                  # 8-byte name  (even)
PY

DOCS="a.sgm ab.sgm w16.sgm w16b.sgm"
CONFIGS="
fixed-unicode|SP_CHARSET_FIXED=YES SP_ENCODING=UNICODE
fixed-utf16|SP_CHARSET_FIXED=YES SP_ENCODING=UTF-16
"

# Run BIN over the matrix; stdout and stderr are binary here, so both go through
# od. stderr loses its argv0 prefix (it differs per binary) — and note that the
# reference MANGLES that prefix, which is part of what we are not reproducing.
run_matrix() {
  local bin="$1" out="$2"
  : > "$out"
  while IFS='|' read -r name env; do
    [ -n "$name" ] || continue
    for doc in $DOCS; do
      ( cd "$WORK" && env -u SP_ENCODING -u SP_BCTF -u SP_CHARSET_FIXED $env \
          "$bin" "$doc" > cell.out 2> cell.err )
      local rc=$?
      {
        printf '=== %s %s rc=%d\n' "$name" "$doc" "$rc"
        od -An -c "$WORK/cell.out"
        printf -- '--- stderr\n'
        LC_ALL=C sed 's/^[^:]*:/PROG:/' "$WORK/cell.err" | od -An -c
      } >> "$out"
    done
  done <<< "$CONFIGS"
}

run_matrix "$BIN" "$WORK/ours.txt"

if [ "$BLESS" -eq 1 ]; then
  cp "$WORK/ours.txt" "$HERE/deviation-expected.txt"
  echo "deviation: blessed $(grep -c '^=== ' "$WORK/ours.txt") cells from $BIN (OUR behaviour, on purpose)"
  exit 0
fi

if [ ! -f "$HERE/deviation-expected.txt" ]; then
  echo "deviation: NO GOLDEN (run --bless with the Scaly binary)"; exit 1
fi

rc=0
if diff -q "$HERE/deviation-expected.txt" "$WORK/ours.txt" > /dev/null; then
  echo "deviation: PASS ($(grep -c '^=== ' "$WORK/ours.txt") cells pin OUR behaviour)"
else
  echo "deviation: FAIL — our behaviour changed"
  diff "$HERE/deviation-expected.txt" "$WORK/ours.txt" | head -40
  rc=1
fi

# Second half: is the reference still broken here? If it agrees with us, the
# deviation has disappeared and the decision to keep it should be revisited.
if command -v onsgmls >/dev/null 2>&1; then
  run_matrix onsgmls "$WORK/ref.txt"
  if diff -q "$WORK/ours.txt" "$WORK/ref.txt" > /dev/null; then
    echo "deviation: NOTE — the reference now AGREES with us in every cell."
    echo "  The deviation documented in this script no longer exists; revisit"
    echo "  COMPLETENESS.md gap (6) and consider deleting this suite."
  else
    echo "deviation: confirmed — the reference still differs ($(diff "$WORK/ours.txt" "$WORK/ref.txt" | grep -c '^<') golden lines)"
  fi
else
  echo "deviation: reference onsgmls not on PATH — skipped the still-deviates check"
fi

exit $rc
