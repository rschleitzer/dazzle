#!/usr/bin/env bash
# tests/sgml/wasm.sh — the SGML corpus against the parser as a web page runs it.
#
#   tests/sgml/wasm.sh [scalyc-binary]
#
# Builds onsgmls for wasm32-wasip1 (web/build.sh, into a scratch
# directory) and replays the whole corpus (tests/sgml/run.sh) through the WASI
# host of a page — its file system in memory, standard input and output handed
# in and out as bytes —, driven from the command line by the host's run.mjs,
# which reads a file from the disk the first time the parser names it and
# writes back what the parser wrote (the -t RAST files). The same models, the
# same goldens as the native binary.
#
# Needs a wasi-sdk and node; SKIPPED by name without either.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

if ! command -v node >/dev/null 2>&1; then
  echo "sgml (wasm): SKIP (no node to run the page's host)"; exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
web/build.sh onsgmls "$TMP" "${1:-}" > "$TMP/build.out" 2>&1
case $? in
  0) ;;
  3) echo "sgml (wasm): SKIP ($(tail -1 "$TMP/build.out"))"; exit 0 ;;
  *) cat "$TMP/build.out"; exit 1 ;;
esac
printf '#!/bin/bash\nexec node --no-warnings %s/run.mjs %s/onsgmls.wasm "$@"\n' "$TMP" "$TMP" > "$TMP/onsgmls"
chmod 755 "$TMP/onsgmls"
tests/sgml/run.sh "$TMP/onsgmls"
