#!/usr/bin/env bash
# dazzle unit suite — the style-engine layer self-tests for the dazzle port
# (Stage 6a).
#
#   tests/dazzle/run.sh [scalyc-binary]   (default: scalyc/build/scalyc)
#
# dazzle.test() chains every module's self-test (ELObj, …) and returns 0 on
# success. `scaly test` runs it on the package ROOT, so dazzle's own bodies are
# in the JIT module (the old --jit harness ran a PROGRAM using dazzle, whose
# bodies became 0-returning stubs -- memory opensp-harness-falsepass); opensp
# comes out of the build cache as an object.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
# the tool beside the compiler: scaly for REPL/run/build/test, scalyc for the flags
SCALY=$("$ROOT/tools/scaly-of.sh" "$BIN")
cd "$ROOT"

# shellcheck disable=SC1091
. tests/platform.sh || exit 1
set -u
if ! scaly_jit_available; then
  echo "dazzle: SKIP (no JIT on this host)"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Expected stderr, in test order: the SchemeParser vector-gating check
# (#( outside dsssl2 -> unknownHash), then the errors-are-LOUD checks
# (undefinedVariableReference; PrimitiveObj::argError name/ordinal/object).
experr="dazzle:E: invalid character after '#'
dazzle:E: reference to undefined variable \"bogusvar\"
dazzle:E: 2nd argument for primitive \"string-append\" of wrong type: \"3\" not a string"
out="$("$SCALY" test packages/dazzle/0.1.0/dazzle.scaly dazzle.test 2>"$TMP/err")"
rc=$?
err="$(scaly_lf < "$TMP/err")"
if [ "$rc" -ne 0 ] || [ "$out" != "$(printf 'test dazzle.test ... ok\n1 passed')" ] || [ "$err" != "$experr" ]; then
  echo "dazzle: FAIL (rc=$rc) out='$out' err='$err'"
  exit 1
fi

echo "dazzle: PASS"
exit 0
