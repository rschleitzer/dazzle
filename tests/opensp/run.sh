#!/usr/bin/env bash
# opensp unit suite — the foundation + declaration-parser self-tests for the
# dazzle/OpenSP port: every `test` function of the package, run by
# `scaly test` on the package root.
#
#   tests/opensp/run.sh [scalyc-binary]   (default: scalyc/build/scalyc)
#
# HISTORY: the first harness ran `scalyc
# --jit unit.scaly`, a PROGRAM that uses opensp -- the package bodies were
# undefined externals the ORC JIT filled with 0-returning stubs, so every test
# "passed" and nothing ran. `scaly test` compiles the package as the ROOT, so
# its bodies are in the JIT module; a deliberately broken test fails
# (checked 2026-09-30). The JIT does not run on the Windows box: SKIP there.
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
# the tool beside the compiler: scaly for REPL/run/build/test, scalyc for the flags
SCALY=$("$ROOT/tools/scaly-of.sh" "$BIN")
cd "$ROOT"

. tests/platform.sh || exit 1
if ! scaly_jit_available; then
  echo "opensp: SKIP (no JIT on this host)"
  exit 0
fi

out="$("$SCALY" test packages/opensp/0.1.0/opensp.scaly 2>&1)"
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | tail -1 | grep -q ' passed$'; then
  echo "opensp: PASS ($(echo "$out" | tail -1))"
  exit 0
fi
echo "opensp: FAIL (rc=$rc)"
echo "$out" | grep -v ' \.\.\. ok$' | tail -8
exit 1
