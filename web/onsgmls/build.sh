#!/usr/bin/env bash
# web/onsgmls/build.sh — the SGML parser for a web page.
#
#   web/onsgmls/build.sh [out-dir] [scalyc-binary]
#     out-dir        where the page's files go (default: this directory)
#     scalyc-binary  compiler to use (default: tests/toolchain.sh — the
#                    installed scalyc, or SCALYC)
#
# Builds packages/opensp/<version>/programs/onsgmls.scaly for wasm32-wasip1
# (`scaly build --target wasm32-wasip1 --release`, the wasi-sdk's clang as the
# C compiler) into <out-dir>/onsgmls.wasm and copies the WASI host a page runs
# it on from the Scaly installation: web/wasi.mjs of its standard library,
# and web/run.mjs, which drives that host from the command line (the gate
# tests/sgml/wasm.sh runs the corpus through it). The page is index.html here;
# serve the directory over HTTP (a module is not loaded from a file: URL):
#
#   web/onsgmls/build.sh && python3 -m http.server -d web/onsgmls
#
# Needs a wasi-sdk ($WASI_SDK, else ~/opt/wasi-sdk-*); exit 3 without one.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$HERE}"
cd "$ROOT"

# shellcheck disable=SC1091
. tests/toolchain.sh "${2:-}" || exit 2
set -u

wasi="${WASI_SDK:-}"
if [ -z "$wasi" ]; then
  for cand in "$HOME"/opt/wasi-sdk-*; do [ -d "$cand" ] && wasi="$cand"; done
fi
if [ -z "$wasi" ] || [ ! -x "$wasi/bin/clang" ]; then
  echo "onsgmls (wasm): no wasi-sdk (set WASI_SDK)"; exit 3
fi

# the Scaly installation: SCALY_HOME, else the one the runtime archive is in
home="${SCALY_HOME:-$(cd "$(dirname "$LIBSCALY")/.." 2>/dev/null && pwd)}"
web=$(ls -d "$home"/packages/scaly/*/web 2>/dev/null | sort -V | tail -1)
if [ -z "$web" ] || [ ! -f "$web/wasi.mjs" ]; then
  echo "onsgmls (wasm): FAIL — no web/wasi.mjs in the standard library of $home"; exit 1
fi

mkdir -p "$OUT" || exit 1
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# the tool's C compiler: the wasi-sdk's clang over its sysroot
printf '#!/bin/sh\nexec "%s/bin/clang" --sysroot="%s/share/wasi-sysroot" "$@"\n' "$wasi" "$wasi" > "$TMP/cc"
chmod 755 "$TMP/cc"

src="packages/opensp/$(tools/version.sh opensp)/programs/onsgmls.scaly"
if ! SCALY_CC="$TMP/cc" "$SCALY" build --target wasm32-wasip1 --release "$src" -o "$OUT/onsgmls.wasm" > "$TMP/build.log" 2>&1; then
  echo "onsgmls (wasm): FAIL (build)"; tail -8 "$TMP/build.log"; exit 1
fi
cp "$web/wasi.mjs" "$web/run.mjs" "$OUT/" || exit 1
echo "onsgmls (wasm): built $OUT/onsgmls.wasm ($(wc -c < "$OUT/onsgmls.wasm" | tr -d ' ') bytes), host from $web"
