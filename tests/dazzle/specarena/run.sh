#!/usr/bin/env bash
# tests/dazzle/specarena/run.sh — gate for the per-document SPEC PARSE ARENA
# (DssslSpecEventHandler, `DZ_SPEC_ARENA`) and for the location PINNING it
# rests on (opensp Origin.pin).
#
#   tests/dazzle/specarena/run.sh [scalyc-binary]
#
# A style sheet is 38 SGML documents, not one, and each parse used to live to
# program end. The arena releases each document's parse when its walk is done —
# which is only sound because everything the walk KEEPS was copied onto the
# handler's host first. The fixtures here are the five places that copy-out is
# read back, and they are all DIAGNOSTICS, because a diagnostic is the only
# thing that reads a Location after the parse that made it:
#
#   useloss  PartHeader.ref_loc of a USE reference          (missingPart)
#   noparts  Doc.loc                                        (noParts)
#   extspec  PartHeader.ref_loc of a SPECID across documents
#   extok    ★the CHUNK TABLE of an EXTERNAL document's body, resolving a
#            RUNTIME error into an entity-expanded `.scm` — the decisive one:
#            it reads, after every parse is over, through exactly the arena
#            that fell
#   content  a CONDITION-(b) document (CONTENT= entity body keeps a pointer
#            INTO its parse) — its arena must be HELD, and the counter says so
#
# ★Both paths are checked. The audit that says "nothing else escapes" is the
# kind of claim that is invisible when it is wrong (cf. the frame mark's store
# sweep, 2026-08-06), so `DZ_SPEC_ARENA=0` is a real escape hatch and gets the
# same golden — and the run with it OFF must report zero releases, or the
# hatch is decoration.
#
# The goldens are the reference dazzle's output (argv0 normalized to PROG),
# with the one documented deviation recorded in expected.notes.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
trap 'rm -rf "$(dirname "$OUT")"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "specarena: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

fail=0
run_case() { # $1 case, $2 mode-label, $3.. env
  local c="$1" mode="$2"; shift 2
  ( cd "$HERE" && SCALY_HOME="$ROOT" env "$@" "$OUT" -t sgml -d "$c.dsl" doc.sgml ) \
      > "$OUT.$c.$mode.out" 2> "$OUT.$c.$mode.err"
  echo "rc=$?" >> "$OUT.$c.$mode.out"
  sed -i.bak "s#^$OUT#PROG#" "$OUT.$c.$mode.err" && rm -f "$OUT.$c.$mode.err.bak"
  cat "$OUT.$c.$mode.err" "$OUT.$c.$mode.out" > "$OUT.$c.$mode"
  if ! cmp -s "$OUT.$c.$mode" "$HERE/$c.expected"; then
    echo "specarena: FAIL $c ($mode)"
    diff "$HERE/$c.expected" "$OUT.$c.$mode" | head -10
    fail=1
  fi
}

for c in useloss noparts extspec extok content; do
  run_case "$c" on  DZ_SPEC_ARENA=1
  run_case "$c" off DZ_SPEC_ARENA=0
done
[ "$fail" = 0 ] || exit 1

# --- the mechanism must ENGAGE, and the escape hatch must really switch it off
got="$(cd "$HERE" && SCALY_HOME="$ROOT" DZ_SPEC_ARENA_STATS=1 "$OUT" -t sgml -d extok.dsl doc.sgml 2>&1 | grep '^specarena:')"
want="specarena: documents released 2, held 0"
if [ "$got" != "$want" ]; then
  echo "specarena: FAIL engaged (want '$want', got '$got')"; exit 1
fi

# condition (b): a CONTENT= entity body holds its document's parse
got="$(cd "$HERE" && SCALY_HOME="$ROOT" DZ_SPEC_ARENA_STATS=1 "$OUT" -t sgml -d content.dsl doc.sgml 2>&1 | grep '^specarena:')"
want="specarena: documents released 0, held 1"
if [ "$got" != "$want" ]; then
  echo "specarena: FAIL condition-b (want '$want', got '$got')"; exit 1
fi

# the escape hatch
got="$(cd "$HERE" && SCALY_HOME="$ROOT" DZ_SPEC_ARENA=0 DZ_SPEC_ARENA_STATS=1 "$OUT" -t sgml -d extok.dsl doc.sgml 2>&1 | grep '^specarena:')"
want="specarena: documents released 0, held 0"
if [ "$got" != "$want" ]; then
  echo "specarena: FAIL escape-hatch (want '$want', got '$got')"; exit 1
fi

echo "specarena: PASS (5 fixtures x 2 modes; arena engaged, condition (b) holds, DZ_SPEC_ARENA=0 disables)"
