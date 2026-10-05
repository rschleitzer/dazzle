#!/usr/bin/env bash
# tests/dazzle/fot/textrun-deviation.sh — the SECOND deliberate deviation from
# the C++ reference, pinned so it cannot drift silently.
#
#   tests/dazzle/fot/textrun-deviation.sh <dazzle-cli-binary>
#   tests/dazzle/fot/textrun-deviation.sh --bless        re-mint the golden
#                                                        (needs `dazzle` on PATH)
#
# WHAT DEVIATES.  In the `-t fot` dump, adjacent character data is emitted as a
# run of `<text>` elements, and WHERE that run is broken differs: on this
# fixture the reference writes 52 blocks, we write 41.
#
# WHY IT IS NOT A DEFECT.  The reference's break points are an artifact of its
# INPUT BUFFERING: `Parser::extendData` scans with `tokenCharInBuffer`, which
# answers end-of-entity at the end of the current read block, so a data token
# can never cross one — and OpenSP reads 8192 raw bytes at a time
# (PosixStorage.cxx:78, `defaultBlockSize`). Compile the reference with another
# block size and ITS OWN output moves. That is a property of Clark's buffer, not
# of DSSSL or of the flow object tree.
#
# Measured 2026-08-05, on `dazzledoc -t fot` (977 K, 24 361 text blocks — the
# largest fot output we have):
#   * concatenating adjacent text runs makes the two outputs BYTE-IDENTICAL:
#     every other flow object, every attribute, every character agrees;
#   * the grove cannot see it — `(node-list-length (children ...))` over a text
#     longer than a read block is 20 000 on both sides, so no stylesheet can
#     observe the difference;
#   * `-t rtf`, `-t tex`, the ESIS corpus (469/469) and every suite are
#     unaffected.
#
# WHAT WE GAIN.  Reproducing the artifact costs one data EVENT PER CHARACTER
# (`Parser.extend_data` would have to stop at every read-block bound). Measured
# on the large-model tier: 19.26 M allocations and 865 MB of region churn
# for 6.16 MB of input, and the port's worst instruction ratio against openjade
# (5.16x on a parse the reference does in 0.76 G). With one event per data RUN
# that case drops to 1.84x.
#
# THE CHECK BELOW IS DELIBERATELY TIGHT.  It removes EXACTLY the boundary
# between two adjacent text runs (`</text><text>`) and nothing else, then
# demands byte identity. A wrong character, a lost flow object, a changed
# attribute or a text run that lands in the wrong place all survive that
# normalisation and fail. It also asserts the raw outputs still DIFFER: if they
# ever stop differing, this pin is stale and belongs deleted, not kept.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
GOLDEN="$HERE/textrun.reference-fot"

if [ "${1:-}" = "--bless" ]; then
  command -v dazzle >/dev/null 2>&1 || { echo "textrun-deviation: --bless needs the reference \`dazzle\` on PATH"; exit 2; }
  ( cd "$HERE" && dazzle -t fot -d textrun.dsl -o "$GOLDEN" textrun.sgml ) || exit 1
  echo "textrun-deviation: re-minted $GOLDEN"
  exit 0
fi

BIN="${1:?usage: textrun-deviation.sh <dazzle-cli-binary>}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

( cd "$HERE" && SCALY_HOME="$ROOT" "$BIN" -t fot -d textrun.dsl -o "$TMP/ours.fot" textrun.sgml ) 2> "$TMP/err" || {
  echo "textrun-deviation: FAIL (run)"; cat "$TMP/err"; exit 1; }
[ -s "$TMP/err" ] && { echo "textrun-deviation: FAIL (unexpected stderr)"; cat "$TMP/err"; exit 1; }

# join adjacent text runs on BOTH sides — nothing else is touched
norm() { python3 -c "
import re,sys
d=open(sys.argv[1],encoding='utf-8',errors='surrogateescape').read()
sys.stdout.write(re.sub(r'</text>\n?<text>','',d))
" "$1"; }

norm "$TMP/ours.fot" > "$TMP/ours.norm"
norm "$GOLDEN"       > "$TMP/ref.norm"

if ! cmp -s "$TMP/ours.norm" "$TMP/ref.norm"; then
  echo "textrun-deviation: FAIL — the difference is NOT just text-run boundaries"
  diff "$TMP/ref.norm" "$TMP/ours.norm" | head -12
  exit 1
fi

if cmp -s "$TMP/ours.fot" "$GOLDEN"; then
  echo "textrun-deviation: FAIL — outputs are byte-identical again; this pin is"
  echo "  stale. Delete the deviation (and this script), do not keep it."
  exit 1
fi

o=$(grep -c '<text>' "$TMP/ours.fot"); r=$(grep -c '<text>' "$GOLDEN")
echo "textrun-deviation: PASS (text runs: ours $o, reference $r; content identical)"
