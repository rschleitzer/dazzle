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
# shellcheck disable=SC1091
. tests/platform.sh || exit 1
set -u

# The Windows box (tests/platform.sh): the .exe lands at $OUT.exe and $OUT is
# the two-line front end over tests/win32/lf-wrapper.sh that CI's rung 7 runs
# the corpus through — the CRT's TEXT-mode stdout and a `C:\…` argv[0] would
# otherwise fail every ESIS and diagnostic comparison (the wrapper's header
# has both accounts). Same shape as tests/dazzle/build-cli.sh.
front_end() {
  printf '#!/bin/bash\nLFW_BIN=%s LFW_NAME="$0" exec %s "$@"\n' \
         "$1" "$ROOT/tests/win32/lf-wrapper.sh" > "$OUT" || exit 1
  chmod +x "$OUT"
}
# ★NOT `$OUT.exe`: msys maps a path WITHOUT an extension onto an existing
# `.exe` of the same stem — for writing too — so `> "$OUT"` overwrote the
# freshly linked binary with the two-line script, which then exec'd itself
# without end (measured 2026-09-20: every corpus entry hung). A different stem
# keeps the two files apart.
EXE="$OUT"
[ "$SCALY_COFF" = 1 ] && EXE="$OUT-native.exe"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- the one tool (ROADMAP-public.md, stage C) ------------------------------
# On a POSIX host the binary is `scaly build --release`: every package as
# bitcode out of the build cache, the whole program linked, optimised and
# emitted as one module in the compiler's own process -- what steps 1 to 3
# below did with llvm-link, sed, opt, llc and ar through tools/link-lto.sh
# (deleted 2026-10-01).
# Measured 2026-10-01 against that route: tests/dazzle/perf-survey.sh reads the
# same wall, cpu and peak RSS in every row, the binary is within 1 % of its
# size, and the build takes less than half the time. What stays of the old
# route is the ARITY GATE (tools/arity-audit.py over each package's IR), which
# the compiler does not diagnose yet.
# SCALYC_NO_LTO=1 and the Windows box (no bitcode route there yet: its
# whole-program link is tools/win-lto.sh) take the archive steps below.
if [ "$SCALY_COFF" = 0 ] && [ "${SCALYC_NO_LTO:-0}" != "1" ]; then
  if command -v python3 >/dev/null 2>&1; then
    for PKG in opensp; do
      if ! "$BIN" -S --no-prelude -o "$TMP/$PKG.ll" "packages/$PKG/0.1.0/$PKG.scaly" > "$TMP/$PKG-emit.log" 2>&1; then
        echo "onsgmls: FAIL ($PKG emit)"; tail -8 "$TMP/$PKG-emit.log"; exit 1
      fi
      if ! python3 "$ROOT/tools/arity-audit.py" "$TMP/$PKG.ll" > "$TMP/$PKG-arity.log" 2>&1; then
        echo "onsgmls: FAIL ($PKG arity)"; cat "$TMP/$PKG-arity.log"; exit 1
      fi
    done
  fi
  RELEASE=--release
  if ! "$BIN" build packages/opensp/0.1.0/onsgmls.scaly $RELEASE -o "$EXE" > "$TMP/build.log" 2>&1; then
    echo "onsgmls: FAIL (build)"; tail -8 "$TMP/build.log"; exit 1
  fi
  echo "onsgmls: built $OUT (whole-program LTO)"
  exit 0
fi

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
# (the Windows box: libscaly.lib, built as CI's rung 3 builds it)
if [ "$SCALY_COFF" = 1 ]; then
  [ -f /tmp/libscaly.lib ] || tools/win-archive.sh "$BIN" > "$TMP/rt.log" 2>&1 || { echo "onsgmls: FAIL (runtime archive)"; tail -8 "$TMP/rt.log"; exit 1; }
elif [ ! -f /tmp/libscaly.a ]; then
  "$BIN" -S --no-prelude --no-tests -o /tmp/libscaly.ll packages/scaly/0.1.0/scaly.scaly > "$TMP/rt.log" 2>&1 || { echo "onsgmls: FAIL (runtime emit)"; tail -8 "$TMP/rt.log"; exit 1; }
  sed 's/^define linkonce_odr /define weak_odr /' /tmp/libscaly.ll > /tmp/libscaly_weak.ll
  "$OPT" -O2 /tmp/libscaly_weak.ll -o /tmp/libscaly_opt.bc >> "$TMP/rt.log" 2>&1 || { echo "onsgmls: FAIL (runtime opt)"; tail -8 "$TMP/rt.log"; exit 1; }
  "$LLC" -relocation-model=pic -O2 -filetype=obj /tmp/libscaly_opt.bc -o /tmp/libscaly.o >> "$TMP/rt.log" 2>&1 || { echo "onsgmls: FAIL (runtime llc)"; tail -8 "$TMP/rt.log"; exit 1; }
  tools/fcontext.sh /tmp/fcontext.o >> "$TMP/rt.log" 2>&1
  tools/eio.sh /tmp/eio.o >> "$TMP/rt.log" 2>&1
  tools/ctime.sh /tmp/ctime.o >> "$TMP/rt.log" 2>&1
  tools/panic.sh /tmp/panic.o >> "$TMP/rt.log" 2>&1
  ar rcs /tmp/libscaly.a /tmp/libscaly.o /tmp/fcontext.o /tmp/eio.o /tmp/ctime.o /tmp/panic.o
fi

# --- 3. link the program against the archives ----------------------------
# (the whole-program build is the tool's, above; this is the route of the
# Windows box and of SCALYC_NO_LTO=1)
if ! "$BIN" -o "$EXE" packages/opensp/0.1.0/onsgmls.scaly "$TMP/libopensp.a" > "$TMP/link.log" 2>&1; then
  echo "onsgmls: FAIL (link)"; tail -8 "$TMP/link.log"; exit 1
fi
echo "onsgmls: built $EXE"
[ "$EXE" = "$OUT" ] || front_end "$EXE"
