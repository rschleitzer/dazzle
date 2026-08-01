#!/usr/bin/env bash
# tests/sgml/build-onsgmls.sh — build the Scaly onsgmls event-dump drop-in.
#
#   tests/sgml/build-onsgmls.sh [out-binary] [scalyc-binary]
#     out-binary    where to write the linked binary (default: /tmp/scaly-onsgmls)
#     scalyc-binary compiler to use  (default: scalyc/build/scalyc)
#
# AOT-compiles the opensp package into an archive (the JIT stubs opensp bodies —
# see tests/opensp/run.sh) and links packages/opensp/0.1.0/onsgmls.scaly against
# it + the scaly runtime archive. Point tests/sgml/run.sh at the result:
#
#   tests/sgml/build-onsgmls.sh && tests/sgml/run.sh /tmp/scaly-onsgmls

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${1:-/tmp/scaly-onsgmls}"
BIN="${2:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"

# shellcheck disable=SC1091
source tools/llvm-env.sh >/dev/null 2>&1
set -u

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- 1. opensp package -> archive -----------------------------------------
if ! "$BIN" -S --no-prelude -o "$TMP/opensp.ll" packages/opensp/0.1.0/opensp.scaly > "$TMP/emit.log" 2>&1; then
  echo "onsgmls: FAIL (opensp emit)"; tail -8 "$TMP/emit.log"; exit 1
fi
sed 's/^define linkonce_odr /define weak_odr /' "$TMP/opensp.ll" > "$TMP/opensp_weak.ll"
if ! "$LLC" -relocation-model=pic -O2 -filetype=obj "$TMP/opensp_weak.ll" -o "$TMP/opensp.o" > "$TMP/llc.log" 2>&1; then
  echo "onsgmls: FAIL (opensp llc)"; tail -8 "$TMP/llc.log"; exit 1
fi
ar rcs "$TMP/libopensp.a" "$TMP/opensp.o"

# --- 2. runtime archive (build if a bare checkout lacks it) ---------------
if [ ! -f /tmp/libscaly.a ]; then
  "$BIN" -S --no-prelude --no-tests -o /tmp/libscaly.ll packages/scaly/0.1.0/scaly.scaly > "$TMP/rt.log" 2>&1 || { echo "onsgmls: FAIL (runtime emit)"; tail -8 "$TMP/rt.log"; exit 1; }
  sed 's/^define linkonce_odr /define weak_odr /' /tmp/libscaly.ll > /tmp/libscaly_weak.ll
  "$OPT" -O2 /tmp/libscaly_weak.ll -o /tmp/libscaly_opt.bc >> "$TMP/rt.log" 2>&1 || { echo "onsgmls: FAIL (runtime opt)"; tail -8 "$TMP/rt.log"; exit 1; }
  "$LLC" -relocation-model=pic -O2 -filetype=obj /tmp/libscaly_opt.bc -o /tmp/libscaly.o >> "$TMP/rt.log" 2>&1 || { echo "onsgmls: FAIL (runtime llc)"; tail -8 "$TMP/rt.log"; exit 1; }
  tools/fcontext.sh /tmp/fcontext.o >> "$TMP/rt.log" 2>&1
  tools/eio.sh /tmp/eio.o >> "$TMP/rt.log" 2>&1
  tools/ctime.sh /tmp/ctime.o >> "$TMP/rt.log" 2>&1
  ar rcs /tmp/libscaly.a /tmp/libscaly.o /tmp/fcontext.o /tmp/eio.o /tmp/ctime.o
fi

# --- 3. link the program --------------------------------------------------
if ! "$BIN" -o "$OUT" packages/opensp/0.1.0/onsgmls.scaly "$TMP/libopensp.a" > "$TMP/link.log" 2>&1; then
  echo "onsgmls: FAIL (link)"; tail -8 "$TMP/link.log"; exit 1
fi
echo "onsgmls: built $OUT"
