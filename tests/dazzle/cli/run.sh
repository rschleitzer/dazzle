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

# Inc-7 stderr fidelity: interpreter diagnostics carry the MessageReporter
# location prefix (<argv0>:<file>:<line>:<col>:<sev>:) resolved through the
# gathered style-spec body's chunk table into the external trace.scm entity,
# and -G disables tail-call replacement + prints the `called from here`
# backtrace. Golden (trace.expected, argv0 normalized to PROG) validated
# byte-identical against the reference openjade 1.3.2 incl. stdout `abc`.
# run from $HERE with RELATIVE paths — the displayed entity file name is the
# sysid resolved against the .dsl's directory as given (`trace.scm`).
got11="$(cd "$HERE" && SCALY_HOME="$ROOT" "$OUT" -G -t sgml -d trace.dsl suite.sgml 2>"$OUT.trerr")"
rc11=$?
err11="$(sed "s|^$OUT|PROG|" "$OUT.trerr")"
want11="$(cat "$HERE/trace.expected")"
if [ "$rc11" -ne 0 ] || [ "$got11" != "abc" ] || [ "$err11" != "$want11" ]; then
  echo "dazzle-cli: FAIL trace (rc=$rc11)"
  echo "  out:  $(printf '%s' "$got11" | cat -v)"
  echo "  want: $(printf '%s' "$want11" | cat -v)"
  echo "  err:  $(printf '%s' "$err11" | cat -v)"
  exit 1
fi

# -V runtime variables (StyleEngine::defineVariable + the parseSpec cmdline
# part): name=value -> string, bare name -> #t, and the cmdline part parses
# BEFORE the stylesheet's parts, so -V mode=cli overrides the sheet's
# (define mode "sheet"). Golden minted from the reference dazzle.
got12="$(cd "$HERE" && SCALY_HOME="$ROOT" "$OUT" -t sgml -d vdef.dsl -V mode=cli -V dbg axis.sgml 2>/dev/null)"
rc12=$?
want12="$(cat "$HERE/vdef.expected")"
if [ "$rc12" -ne 0 ] || [ "$got12" != "$want12" ]; then
  echo "dazzle-cli: FAIL -V runtime variables (rc=$rc12)"
  echo "  want: $(printf '%s' "$want12" | cat -v)"
  echo "  got:  $(printf '%s' "$got12" | cat -v)"
  exit 1
fi

# -E error limit (ParserApp): the document parse stops at the limit, prints
# the errorLimitExceeded info line, rc=1 (doc-parse errors only). stderr
# golden argv0-normalized, minted from the reference dazzle.
got13="$(cd "$HERE" && SCALY_HOME="$ROOT" "$OUT" -E 2 -t sgml -d vdef.dsl -V mode=cli -V dbg elimit.sgml 2>"$OUT.elerr")"
rc13=$?
err13="$(sed 's|^[^:]*:|PROG:|' "$OUT.elerr")"
want13="$(cat "$HERE/elimit.expected")"
wanterr13="$(cat "$HERE/elimit.expected.err")"
if [ "$rc13" -ne 1 ] || [ "$got13" != "$want13" ] || [ "$err13" != "$wanterr13" ]; then
  echo "dazzle-cli: FAIL -E error limit (rc=$rc13)"
  echo "  want: $(printf '%s' "$want13" | cat -v)"
  echo "  got:  $(printf '%s' "$got13" | cat -v)"
  echo "  err:  $(printf '%s' "$err13" | cat -v)"
  exit 1
fi

echo "dazzle-cli: PASS"
