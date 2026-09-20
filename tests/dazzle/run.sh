#!/usr/bin/env bash
# dazzle unit suite — the style-engine layer self-tests for the dazzle port
# (Stage 6a, ROADMAP-dazzle.md).
#
#   tests/dazzle/run.sh [scalyc-binary]   (default: scalyc/build/scalyc)
#
# dazzle.test() chains every module's self-test (ELObj, …) and returns 0 on
# success. Mirrors tests/opensp/run.sh: compile the packages AHEAD-OF-TIME
# into real archives and link + run unit.scaly against them — never --jit
# (undefined externals would become 0-returning stubs and the suite would
# false-pass; memory opensp-harness-falsepass).

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"

# shellcheck disable=SC1091
source tools/llvm-env.sh >/dev/null 2>&1
# shellcheck disable=SC1091
. tests/platform.sh || exit 1
set -u

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- 1. AOT-compile the dazzle and opensp packages into archives -----------
for PKG in dazzle opensp; do
  if ! "$BIN" -S --no-prelude -o "$TMP/$PKG.ll" "packages/$PKG/0.1.0/$PKG.scaly" > "$TMP/$PKG-emit.log" 2>&1; then
    echo "dazzle: FAIL ($PKG emit)"; tail -8 "$TMP/$PKG-emit.log"; exit 1
  fi
  sed 's/^define linkonce_odr /define weak_odr /' "$TMP/$PKG.ll" > "$TMP/${PKG}_weak.ll"
  if ! "$LLC" -relocation-model=pic -O2 -filetype=obj "$TMP/${PKG}_weak.ll" -o "$TMP/$PKG.o" > "$TMP/$PKG-llc.log" 2>&1; then
    echo "dazzle: FAIL ($PKG llc)"; tail -8 "$TMP/$PKG-llc.log"; exit 1
  fi
  ar rcs "$TMP/lib$PKG.a" "$TMP/$PKG.o"
done

# --- 2. Ensure the scaly runtime archive the program links against exists --
# (the Windows box: libscaly.lib, built as CI's rung 3 builds it)
if [ "$SCALY_COFF" = 1 ]; then
  [ -f /tmp/libscaly.lib ] || tools/win-archive.sh "$BIN" > "$TMP/rt.log" 2>&1 || { echo "dazzle: FAIL (runtime archive)"; tail -8 "$TMP/rt.log"; exit 1; }
elif [ ! -f /tmp/libscaly.a ]; then
  "$BIN" -S --no-prelude --no-tests -o /tmp/libscaly.ll packages/scaly/0.1.0/scaly.scaly > "$TMP/rt.log" 2>&1 || { echo "dazzle: FAIL (runtime emit)"; tail -8 "$TMP/rt.log"; exit 1; }
  sed 's/^define linkonce_odr /define weak_odr /' /tmp/libscaly.ll > /tmp/libscaly_weak.ll
  "$OPT" -O2 /tmp/libscaly_weak.ll -o /tmp/libscaly_opt.bc >> "$TMP/rt.log" 2>&1 || { echo "dazzle: FAIL (runtime opt)"; tail -8 "$TMP/rt.log"; exit 1; }
  "$LLC" -relocation-model=pic -O2 -filetype=obj /tmp/libscaly_opt.bc -o /tmp/libscaly.o >> "$TMP/rt.log" 2>&1 || { echo "dazzle: FAIL (runtime llc)"; tail -8 "$TMP/rt.log"; exit 1; }
  tools/fcontext.sh /tmp/fcontext.o >> "$TMP/rt.log" 2>&1
  tools/eio.sh /tmp/eio.o >> "$TMP/rt.log" 2>&1
  tools/ctime.sh /tmp/ctime.o >> "$TMP/rt.log" 2>&1
  tools/panic.sh /tmp/panic.o >> "$TMP/rt.log" 2>&1
  ar rcs /tmp/libscaly.a /tmp/libscaly.o /tmp/fcontext.o /tmp/eio.o /tmp/ctime.o /tmp/panic.o
fi

# --- 3. Link + run the unit harness ---------------------------------------
if ! "$BIN" -o "$TMP/unit$SCALY_EXE" "$HERE/unit.scaly" "$TMP/libdazzle.a" "$TMP/libopensp.a" > "$TMP/link.log" 2>&1; then
  echo "dazzle: FAIL (link)"; tail -8 "$TMP/link.log"; exit 1
fi

# Expected stderr, in test order: the SchemeParser vector-gating check
# (#( outside dsssl2 -> unknownHash), then the errors-are-LOUD checks
# (undefinedVariableReference; PrimitiveObj::argError name/ordinal/object).
experr="dazzle:E: invalid character after '#'
dazzle:E: reference to undefined variable \"bogusvar\"
dazzle:E: 2nd argument for primitive \"string-append\" of wrong type: \"3\" not a string"
out="$("$TMP/unit$SCALY_EXE" 2>"$TMP/err")"
rc=$?
err="$(scaly_lf < "$TMP/err")"
if [ "$rc" -ne 0 ] || [ "$out" != "PASS" ] || [ "$err" != "$experr" ]; then
  echo "dazzle: FAIL (rc=$rc) out='$out' err='$err'"
  exit 1
fi

echo "dazzle: PASS"
exit 0
