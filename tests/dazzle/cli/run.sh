#!/usr/bin/env bash
# tests/dazzle/cli/run.sh — smoke test for the dazzle DSSSL-transform CLI.
#
#   tests/dazzle/cli/run.sh [scalyc-binary]
#
# Builds the CLI (tests/dazzle/build-cli.sh) and runs it over a fixture
# document + stylesheet, diffing the transform output against a golden. Guards
# the full end-to-end pipeline: doc -> opensp parse -> Grove -> DSSSL parse ->
# construction rules -> `make` flow objects -> TransformFOTBuilder -> stdout.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
trap 'rm -rf "$(dirname "$OUT")"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "dazzle-cli: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

got="$("$OUT" -t sgml -d "$HERE/map.dsl" "$HERE/doc.sgml")"
rc=$?
want="$(cat "$HERE/expected.sgml")"
if [ "$rc" -ne 0 ] || [ "$got" != "$want" ]; then
  echo "dazzle-cli: FAIL (rc=$rc)"
  echo "  want: $(printf '%s' "$want" | cat -v)"
  echo "  got:  $(printf '%s' "$got" | cat -v)"
  exit 1
fi

# builtins.dsl prolog: map + node-list->list + apply + attribute-string. Guards
# install_builtins() (the DSSSL Scheme prolog load) end to end. SCALY_HOME is
# set so the prolog resolves regardless of cwd.
got2="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/ids.dsl" "$HERE/suite.sgml")"
rc2=$?
want2="$(cat "$HERE/ids.expected")"
if [ "$rc2" -ne 0 ] || [ "$got2" != "$want2" ]; then
  echo "dazzle-cli: FAIL builtins (rc=$rc2)"
  echo "  want: $(printf '%s' "$want2" | cat -v)"
  echo "  got:  $(printf '%s' "$got2" | cat -v)"
  exit 1
fi

# full DSSSL style-sheet SGML wrapper (<!DOCTYPE STYLE-SHEET> + <STYLE-SPECIFICATION>
# + CDATA body) routed through DssslSpecEventHandler (the -d spec reader). Same
# stylesheet body as ids.dsl, so same golden.
got3="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/wrapped.dsl" "$HERE/suite.sgml")"
rc3=$?
want3="$(cat "$HERE/wrapped.expected")"
if [ "$rc3" -ne 0 ] || [ "$got3" != "$want3" ]; then
  echo "dazzle-cli: FAIL wrapped-spec (rc=$rc3)"
  echo "  want: $(printf '%s' "$want3" | cat -v)"
  echo "  got:  $(printf '%s' "$got3" | cat -v)"
  exit 1
fi

# style-sheet DTD by PUBLIC id (no inline subset) -> forces catalog resolution
# of the shipped dsssl/style-sheet.dtd (STYLE-SHEET forms + DSSSL arch notation).
got4="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/public.dsl" "$HERE/suite.sgml")"
rc4=$?
want4="$(cat "$HERE/public.expected")"
if [ "$rc4" -ne 0 ] || [ "$got4" != "$want4" ]; then
  echo "dazzle-cli: FAIL public-dtd (rc=$rc4)"
  echo "  want: $(printf '%s' "$want4" | cat -v)"
  echo "  got:  $(printf '%s' "$got4" | cat -v)"
  exit 1
fi

# multiline character-data literal: the RE state machine must keep interior
# record-ends as newlines (the bug dropped the first, emitted &#13; for the next).
got5="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/re.dsl" "$HERE/suite.sgml")"
rc5=$?
want5="$(cat "$HERE/re.expected")"
if [ "$rc5" -ne 0 ] || [ "$got5" != "$want5" ]; then
  echo "dazzle-cli: FAIL re-statemachine (rc=$rc5)"
  echo "  want: $(printf '%s' "$want5" | cat -v)"
  echo "  got:  $(printf '%s' "$got5" | cat -v)"
  exit 1
fi

# sibling/axis primitives from the modules reproduction: children over a
# multi-node list, id, node-list-reverse, node-list=?, first-sibling?,
# last-sibling?, child-number, node-list-map.
got6="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/axis.dsl" "$HERE/axis.sgml")"
rc6=$?
want6="$(cat "$HERE/axis.expected")"
if [ "$rc6" -ne 0 ] || [ "$got6" != "$want6" ]; then
  echo "dazzle-cli: FAIL axis-primitives (rc=$rc6)"
  echo "  want: $(printf '%s' "$want6" | cat -v)"
  echo "  got:  $(printf '%s' "$got6" | cat -v)"
  exit 1
fi

echo "dazzle-cli: PASS"
