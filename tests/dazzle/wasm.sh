#!/usr/bin/env bash
# tests/dazzle/wasm.sh — the engine's suites against dazzle as a web page runs
# it.
#
#   tests/dazzle/wasm.sh [scalyc-binary]
#
# Builds dazzle for wasm32-wasip1 (web/build.sh, into a scratch directory) and
# runs every engine suite that tests the program (cli coding engine flowobj
# fot grove html mif pdf prims rtf specarena tex) with it as their prebuilt
# binary (DAZZLE_PREBUILT), under the WASI host of a page -- its file system
# in memory, filled from the disk as the program names a file and written
# back when it ends (the host's run.mjs). The same fixtures, the same goldens
# as the native program: a PDF or a page description made in a page is the
# one made on the command line. framemark is not here: it tests the engine's
# unit tests through the JIT, not the program.
#
# Needs a wasi-sdk and node; SKIPPED by name without either.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

SUITES="cli coding engine flowobj fot grove html mif pdf prims rtf specarena tex"

if ! command -v node >/dev/null 2>&1; then
  echo "dazzle (wasm): SKIP (no node to run the page's host)"; exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
web/build.sh dazzle "$TMP" "${1:-}" > "$TMP/build.out" 2>&1
case $? in
  0) ;;
  3) echo "dazzle (wasm): SKIP ($(tail -1 "$TMP/build.out"))"; exit 0 ;;
  *) cat "$TMP/build.out"; exit 1 ;;
esac
# The suites start the program through tests/dazzle/build-cli.sh's front end,
# which names it in LFW_NAME (what argv[0] would be, and so what its messages
# begin with); a script cannot read the argv[0] it was started under.
printf '#!/bin/bash\nexec node --no-warnings %s/run.mjs --argv0 "${LFW_NAME:-$0}" %s/dazzle.wasm "$@"\n' "$TMP" "$TMP" > "$TMP/dazzle"
chmod 755 "$TMP/dazzle"

pids=(); names=()
for d in $SUITES; do
  ( DAZZLE_PREBUILT="$TMP/dazzle" "tests/dazzle/$d/run.sh" "${1:-}" > "$TMP/$d.log" 2>&1 ) &
  pids+=($!); names+=("$d")
done
failed=""
for i in "${!pids[@]}"; do
  wait "${pids[$i]}" || { failed="$failed ${names[$i]}"; tail -5 "$TMP/${names[$i]}.log"; }
done
n=$(echo $SUITES | wc -w | tr -d ' ')
if [ -n "$failed" ]; then
  echo "dazzle (wasm): FAIL —$failed"; exit 1
fi
echo "dazzle (wasm): $n of $n suites PASS"
