#!/usr/bin/env bash
# web/dazzle/build.sh — the engine's page: dazzle.wasm and the WASI host
# beside index.html and pages.mjs here (web/build.sh), then serve this
# directory:
#
#   web/dazzle/build.sh && python3 -m http.server -d web/dazzle
#
#   web/dazzle/build.sh [out-dir] [scalyc-binary]   (out-dir: this directory)
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/../build.sh" dazzle "${1:-$HERE}" "${2:-}"
