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
# Arity gate — see tools/arity-audit.py. A call site that passes fewer
# arguments than its callee reads is a silent miscompile waiting for the
# optimizer to reallocate the register; scalyc does not diagnose it yet, so the
# IR is checked here, before opt can turn it into wrong output.
if command -v python3 >/dev/null 2>&1; then
  if ! python3 "$ROOT/tools/arity-audit.py" "$TMP/opensp.ll" > "$TMP/arity.log" 2>&1; then
    echo "onsgmls: FAIL (opensp arity)"; cat "$TMP/arity.log"; exit 1
  fi
fi
sed 's/^define linkonce_odr /define weak_odr /' "$TMP/opensp.ll" > "$TMP/opensp_weak.ll"
# The IR pipeline (`opt -O2`) before llc — same recipe as the runtime archive
# below. Measured 2026-08-01: llc -O2 alone leaves 1.6-2.0x on the table (the
# ClaML 13.7 MB parse goes 1.25 s -> 0.63 s) at byte-identical output. `opt` is
# optional in tools/llvm-env.sh, so fall back to the bare weak IR without it.
OPTIN="$TMP/opensp_weak.ll"
if [ -n "${OPT:-}" ]; then
  if ! "$OPT" -O2 "$TMP/opensp_weak.ll" -o "$TMP/opensp.bc" > "$TMP/opt.log" 2>&1; then
    echo "onsgmls: FAIL (opensp opt)"; tail -8 "$TMP/opt.log"; exit 1
  fi
  OPTIN="$TMP/opensp.bc"
fi
if ! "$LLC" -relocation-model=pic -O2 -filetype=obj "$OPTIN" -o "$TMP/opensp.o" > "$TMP/llc.log" 2>&1; then
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
# Preferred path: whole-program LTO (tools/link-lto.sh) — one module out of the
# program, the opensp package and the runtime, `opt -O2` across all of it. Worth
# 13 % CPU on a 13.7 MB parse at byte-identical output (tests/dazzle/PERFORMANCE.md),
# because the hot RBMM prologue/epilogue calls stop going through the stub table
# and become inlinable. SCALYC_NO_LTO=1, or a checkout without llvm-link/opt,
# falls back to the archive link below.
LTO_OK=0
RT_LL=""
if [ "${SCALYC_NO_LTO:-0}" != "1" ]; then
  # Emit the runtime IR fresh rather than trusting whatever /tmp/libscaly.ll a
  # previous build left behind — the archive can be current while the IR next
  # to it is stale, and a stale runtime would be linked in silently.
  if "$BIN" -S --no-prelude --no-tests -o "$TMP/scaly_rt.ll" packages/scaly/0.1.0/scaly.scaly > "$TMP/rtll.log" 2>&1; then
    RT_LL="$TMP/scaly_rt.ll"
  fi
fi
if [ -n "$RT_LL" ]; then
  if "$BIN" -S -o "$TMP/onsgmls.ll" packages/opensp/0.1.0/onsgmls.scaly > "$TMP/prog.log" 2>&1; then
    tools/link-lto.sh "$OUT" "$TMP/onsgmls.ll" "$TMP/opensp.ll" "$RT_LL" > "$TMP/lto.log" 2>&1
    rc=$?
    if [ "$rc" = 0 ]; then
      LTO_OK=1
      echo "onsgmls: built $OUT (whole-program LTO)"
    elif [ "$rc" != 3 ]; then
      echo "onsgmls: FAIL (lto)"; tail -8 "$TMP/lto.log"; exit 1
    fi
  fi
fi

if [ "$LTO_OK" = 0 ]; then
  if ! "$BIN" -o "$OUT" packages/opensp/0.1.0/onsgmls.scaly "$TMP/libopensp.a" > "$TMP/link.log" 2>&1; then
    echo "onsgmls: FAIL (link)"; tail -8 "$TMP/link.log"; exit 1
  fi
  echo "onsgmls: built $OUT"
fi
