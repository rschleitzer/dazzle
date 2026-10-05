#!/usr/bin/env bash
# tests/sgml/build-onsgmls.sh — build the Scaly onsgmls event-dump drop-in.
#
#   tests/sgml/build-onsgmls.sh [out-binary] [scalyc-binary]
#     out-binary    where to write the linked binary (default: /tmp/scaly-onsgmls)
#     scalyc-binary compiler to use  (default: tests/toolchain.sh — the
#                   installed scalyc, or SCALYC)
#
# Builds packages/opensp/0.1.0/onsgmls.scaly with the tool (`scaly build
# --release`), from the repository root. Point tests/sgml/run.sh at the result:
#
#   tests/sgml/build-onsgmls.sh && tests/sgml/run.sh /tmp/scaly-onsgmls

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${1:-/tmp/scaly-onsgmls}"
cd "$ROOT"

# shellcheck disable=SC1091
. tests/toolchain.sh "${2:-}" || exit 2
# shellcheck disable=SC1091
. tests/platform.sh || exit 1
set -u

# A Windows shell (tests/platform.sh): the .exe lands at $OUT-native.exe and
# $OUT is the two-line front end over tests/win32/lf-wrapper.sh — a `C:\…`
# argv[0] would otherwise fail every diagnostic comparison (the wrapper's
# header has the account). Same shape as tests/dazzle/build-cli.sh.
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

# --- the one tool -----------------------------------------------------------
# The binary is `scaly build --release`: every package as bitcode out of the
# build cache, the whole program linked, optimised and emitted as one module in
# the compiler's own process. The compiler finds the standard library and the
# runtime archive in its installation and the packages in ./packages here.
# (Until 2026-10-01 this was a hand-rolled pipeline of llvm-link, sed, opt, llc
# and ar, and it stayed as a fallback while these suites lived in the Scaly
# compiler's tree; it needed that project's scripts and went with the move.
# Measured against it then: the same wall, cpu and peak RSS in every row of
# tests/dazzle/perf-survey.sh, a binary within 1 % of its size, less than half
# the build time. The compiler project's arity audit over each package's IR,
# which ran here too, is a gate of the compiler and stayed with it.)
RELEASE=--release
if ! "$SCALY" build packages/opensp/0.1.0/onsgmls.scaly $RELEASE -o "$EXE" > "$TMP/build.log" 2>&1; then
  echo "onsgmls: FAIL (build)"; tail -8 "$TMP/build.log"; exit 1
fi
if [ "$EXE" = "$OUT" ]; then
  echo "onsgmls: built $OUT (whole-program LTO)"
else
  front_end "$EXE"
  echo "onsgmls: built $EXE (whole-program LTO), front end $OUT"
fi
