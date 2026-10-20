#!/usr/bin/env bash
# web/build.sh — a program of this repository for a web page.
#
#   web/build.sh onsgmls|dazzle out-dir [scalyc-binary]
#     out-dir        where the files go
#     scalyc-binary  compiler to use (default: tests/toolchain.sh — the
#                    installed scalyc, or SCALYC)
#
# Builds the program (packages/opensp/<version>/programs/onsgmls.scaly, or
# packages/dazzle/<version>/programs/dazzle.scaly) for wasm32-wasip1 (`scaly
# build --target wasm32-wasip1 --release`, the wasi-sdk's clang as the C
# compiler) into <out-dir>/<program>.wasm and copies the WASI host a page runs
# it on from the Scaly installation: web/wasi.mjs of its standard library, and
# web/run.mjs, which drives that host from the command line (the gates
# tests/sgml/wasm.sh and tests/dazzle/wasm.sh run their suites through it).
# The pages are web/<program>/index.html; web/<program>/build.sh builds into
# its own directory, which is then served over HTTP (a module is not loaded
# from a file: URL).
#
# Needs a wasi-sdk ($WASI_SDK, else ~/opt/wasi-sdk-*); exit 3 without one.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PROGRAM="${1:?usage: web/build.sh onsgmls|dazzle out-dir [scalyc-binary]}"
OUT="${2:?usage: web/build.sh onsgmls|dazzle out-dir [scalyc-binary]}"
case "$PROGRAM" in
  onsgmls) package=opensp ;;
  dazzle)  package=dazzle ;;
  *) echo "web/build.sh: no program $PROGRAM (onsgmls or dazzle)"; exit 2 ;;
esac
cd "$ROOT"

# shellcheck disable=SC1091
. tests/toolchain.sh "${3:-}" || exit 2
set -u

wasi="${WASI_SDK:-}"
if [ -z "$wasi" ]; then
  for cand in "$HOME"/opt/wasi-sdk-*; do [ -d "$cand" ] && wasi="$cand"; done
fi
if [ -z "$wasi" ] || [ ! -x "$wasi/bin/clang" ]; then
  echo "$PROGRAM (wasm): no wasi-sdk (set WASI_SDK)"; exit 3
fi

# the Scaly installation: SCALY_HOME, else the one the runtime archive is in
home="${SCALY_HOME:-$(cd "$(dirname "$LIBSCALY")/.." 2>/dev/null && pwd)}"
web=$(ls -d "$home"/packages/scaly/*/web 2>/dev/null | sort -V | tail -1)
if [ -z "$web" ] || [ ! -f "$web/wasi.mjs" ]; then
  echo "$PROGRAM (wasm): FAIL — no web/wasi.mjs in the standard library of $home"; exit 1
fi

mkdir -p "$OUT" || exit 1
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# the tool's C compiler: the wasi-sdk's clang over its sysroot
printf '#!/bin/sh\nexec "%s/bin/clang" --sysroot="%s/share/wasi-sysroot" "$@"\n' "$wasi" "$wasi" > "$TMP/cc"
chmod 755 "$TMP/cc"

src="packages/$package/$(tools/version.sh $package)/programs/$PROGRAM.scaly"
if ! SCALY_CC="$TMP/cc" "$SCALY" build --target wasm32-wasip1 --release "$src" -o "$OUT/$PROGRAM.wasm" > "$TMP/build.log" 2>&1; then
  echo "$PROGRAM (wasm): FAIL (build)"; tail -8 "$TMP/build.log"; exit 1
fi
cp "$web/wasi.mjs" "$web/run.mjs" "$OUT/" || exit 1
echo "$PROGRAM (wasm): built $OUT/$PROGRAM.wasm ($(wc -c < "$OUT/$PROGRAM.wasm" | tr -d ' ') bytes), host from $web"
