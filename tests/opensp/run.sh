#!/usr/bin/env bash
# opensp unit suite — the foundation-layer self-tests (Stage 1 of the dazzle/
# OpenSP port) run through the in-process JIT, mirroring tests/selfhosted.
#
#   tests/opensp/run.sh [scalyc-binary]   (default: scalyc/build/scalyc)
#
# opensp.test() chains StringC / CodingSystem / Message / Location checks and
# returns 0 on success; the harness prints PASS. As later stages land, extend
# opensp.test() and this suite grows with it.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"

out="$("$BIN" --jit "$HERE/unit.scaly" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "PASS" ]; then
  echo "opensp: PASS"
  exit 0
fi
echo "opensp: FAIL (rc=$rc) out='$out'"
exit 1
