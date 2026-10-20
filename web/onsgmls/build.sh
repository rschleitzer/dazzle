#!/usr/bin/env bash
# web/onsgmls/build.sh — the SGML parser's page: onsgmls.wasm and the WASI
# host beside index.html here (web/build.sh), then serve this directory:
#
#   web/onsgmls/build.sh && python3 -m http.server -d web/onsgmls
#
#   web/onsgmls/build.sh [out-dir] [scalyc-binary]   (out-dir: this directory)
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/../build.sh" onsgmls "${1:-$HERE}" "${2:-}"
