#!/usr/bin/env bash
# opensp unit suite — the foundation + declaration-parser self-tests for the
# dazzle/OpenSP port.
#
#   tests/opensp/run.sh [scalyc-binary]   (default: scalyc/build/scalyc)
#
# opensp.test() chains every module's self-test (StringC, CodingSystem, …,
# Parser) and returns 0 on success. HISTORY (memory opensp-harness-falsepass):
# the old harness ran `scalyc --jit unit.scaly`, but under --jit the opensp
# package bodies are undefined externals the ORC JIT fills with 0-returning
# stubs, so opensp.test() ALWAYS returned 0 and the suite false-passed —
# nothing was ever executed. This harness compiles opensp AHEAD-OF-TIME into a
# real archive and links + runs unit.scaly against it, so opensp.test()
# genuinely runs. A zero return (program prints "PASS") means every check
# passed for real.

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

# --- 1. AOT-compile the opensp package into an archive --------------------
if ! "$BIN" -S --no-prelude -o "$TMP/opensp.ll" packages/opensp/0.1.0/opensp.scaly > "$TMP/emit.log" 2>&1; then
  echo "opensp: FAIL (emit)"; tail -8 "$TMP/emit.log"; exit 1
fi
sed 's/^define linkonce_odr /define weak_odr /' "$TMP/opensp.ll" > "$TMP/opensp_weak.ll"
if ! "$LLC" -relocation-model=pic -O2 -filetype=obj "$TMP/opensp_weak.ll" -o "$TMP/opensp.o" > "$TMP/llc.log" 2>&1; then
  echo "opensp: FAIL (llc)"; tail -8 "$TMP/llc.log"; exit 1
fi
ar rcs "$TMP/libopensp.a" "$TMP/opensp.o"

# --- 2. Ensure the scaly runtime archive the program links against exists --
# (build.sh / tools/bootstrap.sh / tools/seed.sh all produce /tmp/libscaly.a;
#  build it here if a bare checkout runs the suite standalone; the Windows
#  box: libscaly.lib, built as CI's rung 3 builds it)
if [ "$SCALY_COFF" = 1 ]; then
  [ -f /tmp/libscaly.lib ] || tools/win-archive.sh "$BIN" > "$TMP/rt.log" 2>&1 || { echo "opensp: FAIL (runtime archive)"; tail -8 "$TMP/rt.log"; exit 1; }
elif [ ! -f /tmp/libscaly.a ]; then
  "$BIN" -S --no-prelude --no-tests -o /tmp/libscaly.ll packages/scaly/0.1.0/scaly.scaly > "$TMP/rt.log" 2>&1 || { echo "opensp: FAIL (runtime emit)"; tail -8 "$TMP/rt.log"; exit 1; }
  sed 's/^define linkonce_odr /define weak_odr /' /tmp/libscaly.ll > /tmp/libscaly_weak.ll
  "$OPT" -O2 /tmp/libscaly_weak.ll -o /tmp/libscaly_opt.bc >> "$TMP/rt.log" 2>&1 || { echo "opensp: FAIL (runtime opt)"; tail -8 "$TMP/rt.log"; exit 1; }
  "$LLC" -relocation-model=pic -O2 -filetype=obj /tmp/libscaly_opt.bc -o /tmp/libscaly.o >> "$TMP/rt.log" 2>&1 || { echo "opensp: FAIL (runtime llc)"; tail -8 "$TMP/rt.log"; exit 1; }
  tools/fcontext.sh /tmp/fcontext.o >> "$TMP/rt.log" 2>&1
  tools/eio.sh /tmp/eio.o >> "$TMP/rt.log" 2>&1
  tools/ctime.sh /tmp/ctime.o >> "$TMP/rt.log" 2>&1
  tools/panic.sh /tmp/panic.o >> "$TMP/rt.log" 2>&1
  ar rcs /tmp/libscaly.a /tmp/libscaly.o /tmp/fcontext.o /tmp/eio.o /tmp/ctime.o /tmp/panic.o
fi

# --- 3. Link + run the unit harness ---------------------------------------
if ! "$BIN" -o "$TMP/unit$SCALY_EXE" "$HERE/unit.scaly" "$TMP/libopensp.a" > "$TMP/link.log" 2>&1; then
  echo "opensp: FAIL (link)"; tail -8 "$TMP/link.log"; exit 1
fi

out="$("$TMP/unit$SCALY_EXE" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "PASS" ]; then
  echo "opensp: PASS"
  exit 0
fi
echo "opensp: FAIL (rc=$rc) out='$out'"
exit 1
