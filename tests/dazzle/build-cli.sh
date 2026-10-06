#!/usr/bin/env bash
# tests/dazzle/build-cli.sh — build the Scaly dazzle DSSSL-transform CLI.
#
#   tests/dazzle/build-cli.sh [out-binary] [scalyc-binary]
#     out-binary    where to write the linked binary (default: /tmp/dazzle)
#     scalyc-binary compiler to use  (default: tests/toolchain.sh — the
#                   installed scalyc, or SCALYC)
#
# Builds packages/dazzle/0.1.0/programs/dazzle.scaly with the tool (`scaly build
# --release`), from the repository root — the same recipe as
# tests/sgml/build-onsgmls.sh. Compiling the dazzle package needs a 64 MB
# stack (`ulimit -s 65520`). Then, e.g.:
#
#   tests/dazzle/build-cli.sh && /tmp/dazzle -t sgml -d map.dsl doc.xml

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${1:-/tmp/dazzle}"
cd "$ROOT"

# shellcheck disable=SC1091
. tests/toolchain.sh "${2:-}" || exit 2
# shellcheck disable=SC1091
. tests/platform.sh || exit 1
set -u

# What the suites invoke IS $OUT. Where the binary cannot be that file — a
# prebuilt one somewhere else, or the Windows box, where the CRT's TEXT-mode
# stdout would fail every byte comparison — $OUT becomes the two-line front
# end below over tests/win32/lf-wrapper.sh, and the binary lives beside it.
# `LFW_NAME="$0"` inside the front end matters: the wrapper reports argv[0] as
# the path IT was invoked as, and tests/dazzle/cli/run.sh normalises stderr by
# substituting exactly that path.
front_end() {
  printf '#!/bin/bash\nLFW_BIN=%s LFW_NAME="$0" exec %s "$@"\n' \
         "$1" "$ROOT/tests/win32/lf-wrapper.sh" > "$OUT" || exit 1
  chmod +x "$OUT"
}
# A Windows shell (tests/platform.sh): the .exe lands beside the front end.
# ★NOT `$OUT.exe`: msys maps a path WITHOUT an extension onto an existing
# `.exe` of the same stem — for writing too — so `> "$OUT"` would overwrite
# the freshly linked binary with the two-line script (measured 2026-09-20 on
# the onsgmls twin: every corpus entry hung in a wrapper exec'ing itself).
EXE="$OUT"
[ "$SCALY_COFF" = 1 ] && EXE="$OUT-native.exe"

# ★A PREBUILT CLI. tests/run.sh builds the engine ONCE and hands it to every
# suite this way; it began for a host where nothing could compile but the
# suites were worth running — a suite reimplemented for one platform would be
# a SECOND ORACLE, which is the one thing the corpus discipline in this tree
# does not allow. So the single place that produces the binary is also the
# place that can be told one already exists.
#
# What lands at $OUT is not the .exe but tests/win32/lf-wrapper.sh, because the
# suites compare bytes and Windows' CRT hands us a TEXT-mode stdout; the
# wrapper's header has the full reasoning, including why it must NOT touch a
# file the program writes itself. Every suite that calls this script therefore
# works unchanged on Windows.
if [ -n "${DAZZLE_PREBUILT:-}" ]; then
  if [ ! -x "$DAZZLE_PREBUILT" ]; then
    echo "dazzle-cli: FAIL (DAZZLE_PREBUILT=$DAZZLE_PREBUILT is not executable)"
    exit 1
  fi
  # A two-line front end rather than three environment variables the caller
  # would have to keep in step: what the suites invoke IS $OUT, so $OUT is the
  # place that knows which binary it stands for.
  front_end "$DAZZLE_PREBUILT"
  echo "dazzle-cli: using prebuilt $DAZZLE_PREBUILT (via lf-wrapper)"
  exit 0
fi

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
# DAZZLE_NO_OPT=1 builds without the whole-program pass: a memory question of
# the binary, not a speed one -- the packages as cached objects.
RELEASE=--release
[ -n "${DAZZLE_NO_OPT:-}" ] && RELEASE=
if ! "$SCALY" build packages/dazzle/0.1.0/programs/dazzle.scaly $RELEASE -o "$EXE" > "$TMP/build.log" 2>&1; then
  echo "dazzle-cli: FAIL (build)"; tail -8 "$TMP/build.log"; exit 1
fi
if [ "$EXE" = "$OUT" ]; then
  echo "dazzle-cli: built $OUT (whole-program LTO)"
else
  front_end "$EXE"
  echo "dazzle-cli: built $EXE (whole-program LTO), front end $OUT"
fi
