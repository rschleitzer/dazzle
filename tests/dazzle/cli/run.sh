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

# (data nl) over a MULTI-node list concatenates every member's data
# (modules sweep: multi-<return> sprocs were truncated to the first).
got7="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/data.dsl" "$HERE/axis.sgml")"
rc7=$?
want7="$(cat "$HERE/data.expected")"
if [ "$rc7" -ne 0 ] || [ "$got7" != "$want7" ]; then
  echo "dazzle-cli: FAIL data-multinode (rc=$rc7)"
  echo "  want: $(printf '%s' "$want7" | cat -v)"
  echo "  got:  $(printf '%s' "$got7" | cat -v)"
  exit 1
fi

# entity FO whose output file cannot be created: reference reports
# cannotOpenOutputError on stderr, the content falls through to stdout,
# rc stays 0 (the modules sweep ran against un-created output dirs).
got8="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/entityfall.dsl" "$HERE/axis.sgml" 2>"$OUT.eferr")"
rc8=$?
if [ "$rc8" -ne 0 ] || [ "$got8" != "FALLBACK" ] \
   || ! grep -qF ':E: cannot open output file "no_such_dir/out.txt" (No such file or directory)' "$OUT.eferr"; then
  echo "dazzle-cli: FAIL entity-open-fallback (rc=$rc8)"
  echo "  got:  $(printf '%s' "$got8" | cat -v)"
  echo "  err:  $(cat "$OUT.eferr")"
  exit 1
fi

# forward-declared flow-object class (declare-flow-object-class AFTER the make
# that uses it — cql.dsl loads fodeclare.scm last; MakeExpression resolves at
# compile) + node-property with keyword args (tree-root/grove-root/default:).
# Golden validated against the reference dazzle.
got9="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/focfwd.dsl" "$HERE/axis.sgml")"
rc9=$?
want9="$(cat "$HERE/focfwd.expected")"
if [ "$rc9" -ne 0 ] || [ "$got9" != "$want9" ]; then
  echo "dazzle-cli: FAIL foc-forward/node-property (rc=$rc9)"
  echo "  want: $(printf '%s' "$want9" | cat -v)"
  echo "  got:  $(printf '%s' "$got9" | cat -v)"
  exit 1
fi

# with-mode + named modes, ancestor-qualified patterns ((grp test) outranks
# the plain GI rule), define-language/declare-default-language case tables.
# Golden validated against the reference dazzle.
got10="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/langmode.dsl" "$HERE/axis.sgml")"
rc10=$?
want10="$(cat "$HERE/langmode.expected")"
if [ "$rc10" -ne 0 ] || [ "$got10" != "$want10" ]; then
  echo "dazzle-cli: FAIL langmode (rc=$rc10)"
  echo "  want: $(printf '%s' "$want10" | cat -v)"
  echo "  got:  $(printf '%s' "$got10" | cat -v)"
  exit 1
fi

echo "dazzle-cli: PASS"
