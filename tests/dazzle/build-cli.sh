#!/usr/bin/env bash
# tests/dazzle/build-cli.sh — build the Scaly dazzle DSSSL-transform CLI.
#
#   tests/dazzle/build-cli.sh [out-binary] [scalyc-binary]
#     out-binary    where to write the linked binary (default: /tmp/dazzle)
#     scalyc-binary compiler to use  (default: scalyc/build/scalyc)
#
# AOT-compiles the dazzle + opensp packages into archives and links
# packages/dazzle/0.1.0/dazzle_cli.scaly against them + the scaly runtime
# archive (same recipe as tests/sgml/build-onsgmls.sh). Then, e.g.:
#
#   tests/dazzle/build-cli.sh && /tmp/dazzle -t sgml -d map.dsl doc.xml

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${1:-/tmp/dazzle}"
BIN="${2:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"

# shellcheck disable=SC1091
source tools/llvm-env.sh >/dev/null 2>&1
set -u

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- 1. dazzle + opensp packages -> archives ------------------------------
for PKG in dazzle opensp; do
  if ! "$BIN" -S --no-prelude -o "$TMP/$PKG.ll" "packages/$PKG/0.1.0/$PKG.scaly" > "$TMP/$PKG-emit.log" 2>&1; then
    echo "dazzle-cli: FAIL ($PKG emit)"; tail -8 "$TMP/$PKG-emit.log"; exit 1
  fi
  # Arity gate — see tools/arity-audit.py. A call site that passes fewer
  # arguments than its callee reads is a silent miscompile waiting for the
  # optimizer to reallocate the register; scalyc does not diagnose it yet, so
  # the IR is checked here, before opt can turn it into wrong output.
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 "$ROOT/tools/arity-audit.py" "$TMP/$PKG.ll" > "$TMP/$PKG-arity.log" 2>&1; then
      echo "dazzle-cli: FAIL ($PKG arity)"; cat "$TMP/$PKG-arity.log"; exit 1
    fi
  fi
  sed 's/^define linkonce_odr /define weak_odr /' "$TMP/$PKG.ll" > "$TMP/${PKG}_weak.ll"
  # The IR pipeline (`opt -O2`) before llc — same recipe as the runtime archive
  # below. Measured 2026-08-01: llc -O2 alone leaves 1.6-2.0x on the table (the
  # dazzledoc -t fot run goes 2.77 s -> 1.73 s) at byte-identical output. `opt`
  # is optional in tools/llvm-env.sh, so fall back to the bare weak IR.
  #
  # ★Turning this on first surfaced a REAL bug, not an opt bug: FotSink's tex
  # arm called TeXFOTBuilder.start_line_field() one argument short, so the
  # callee read whatever x1 happened to hold — the caller's own `nic`, by luck,
  # until opt reallocated the register. Only `-O0` hid it. If a suite ever
  # breaks under opt again, run the arity audit over the emitted .ll BEFORE
  # suspecting LLVM: a call site whose argument count disagrees with the
  # callee's definition is the signature of this class.
  OPTIN="$TMP/${PKG}_weak.ll"
  if [ -n "${OPT:-}" ]; then
    if ! "$OPT" -O2 "$TMP/${PKG}_weak.ll" -o "$TMP/$PKG.bc" > "$TMP/$PKG-opt.log" 2>&1; then
      echo "dazzle-cli: FAIL ($PKG opt)"; tail -8 "$TMP/$PKG-opt.log"; exit 1
    fi
    OPTIN="$TMP/$PKG.bc"
  fi
  if ! "$LLC" -relocation-model=pic -O2 -filetype=obj "$OPTIN" -o "$TMP/$PKG.o" > "$TMP/$PKG-llc.log" 2>&1; then
    echo "dazzle-cli: FAIL ($PKG llc)"; tail -8 "$TMP/$PKG-llc.log"; exit 1
  fi
  ar rcs "$TMP/lib$PKG.a" "$TMP/$PKG.o"
done

# --- 2. runtime archive (build if a bare checkout lacks it) ---------------
if [ ! -f /tmp/libscaly.a ]; then
  "$BIN" -S --no-prelude --no-tests -o /tmp/libscaly.ll packages/scaly/0.1.0/scaly.scaly > "$TMP/rt.log" 2>&1 || { echo "dazzle-cli: FAIL (runtime emit)"; tail -8 "$TMP/rt.log"; exit 1; }
  sed 's/^define linkonce_odr /define weak_odr /' /tmp/libscaly.ll > /tmp/libscaly_weak.ll
  "$OPT" -O2 /tmp/libscaly_weak.ll -o /tmp/libscaly_opt.bc >> "$TMP/rt.log" 2>&1 || { echo "dazzle-cli: FAIL (runtime opt)"; tail -8 "$TMP/rt.log"; exit 1; }
  "$LLC" -relocation-model=pic -O2 -filetype=obj /tmp/libscaly_opt.bc -o /tmp/libscaly.o >> "$TMP/rt.log" 2>&1 || { echo "dazzle-cli: FAIL (runtime llc)"; tail -8 "$TMP/rt.log"; exit 1; }
  tools/fcontext.sh /tmp/fcontext.o >> "$TMP/rt.log" 2>&1
  tools/eio.sh /tmp/eio.o >> "$TMP/rt.log" 2>&1
  tools/ctime.sh /tmp/ctime.o >> "$TMP/rt.log" 2>&1
  ar rcs /tmp/libscaly.a /tmp/libscaly.o /tmp/fcontext.o /tmp/eio.o /tmp/ctime.o
fi

# --- 3. link the program --------------------------------------------------
if ! "$BIN" -o "$OUT" packages/dazzle/0.1.0/dazzle_cli.scaly "$TMP/libdazzle.a" "$TMP/libopensp.a" > "$TMP/link.log" 2>&1; then
  echo "dazzle-cli: FAIL (link)"; tail -8 "$TMP/link.log"; exit 1
fi
echo "dazzle-cli: built $OUT"
