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
cd "$ROOT"
# shellcheck disable=SC1091
. tests/toolchain.sh "${1:-}" || exit 2
set -u

OUT="$(mktemp -d)/dazzle"
trap 'rm -rf "$(dirname "$OUT")"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" > "$OUT.build.log" 2>&1; then
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
# stylesheet body as ids.dsl, so same golden. The inline subset declares the
# DSSSL architecture the way dsssl/style-sheet.dtd does (ArcBase PI + notation +
# ArcDTD support attributes) — that is what loadDoc's gotArc_ gate requires.
got3="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/wrapped.dsl" "$HERE/suite.sgml" 2>"$OUT.arcerr")"
rc3=$?
want3="$(cat "$HERE/wrapped.expected")"
err3="$(cat "$OUT.arcerr")"
if [ "$rc3" -ne 0 ] || [ "$got3" != "$want3" ] || [ -n "$err3" ]; then
  echo "dazzle-cli: FAIL wrapped-spec (rc=$rc3, err: $err3)"
  echo "  want: $(printf '%s' "$want3" | cat -v)"
  echo "  got:  $(printf '%s' "$got3" | cat -v)"
  exit 1
fi

# ...the same stylesheet MINUS the ArcBase PI: declaring the DSSSL notation does
# NOT declare the architecture as a base architecture, so the spec reader reports
# specNotArc and processes the document with NO construction rules (default
# processing -> the document's own character data). Both reference binaries agree,
# and the too-lenient notation-only gate this pins used to load the rules.
got3b="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/notarc.dsl" "$HERE/suite.sgml" 2>"$OUT.arcerr")"
rc3b=$?
err3b="$(sed "s|^$OUT|PROG|" "$OUT.arcerr")"
if [ "$rc3b" -ne 0 ] || [ "$got3b" != "abc" ] \
   || [ "$err3b" != 'PROG:E: specification document does not have the DSSSL architecture as a base architecture' ]; then
  echo "dazzle-cli: FAIL notarc-spec (rc=$rc3b, err: $err3b)"
  echo "  got:  $(printf '%s' "$got3b" | cat -v)"
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

# sibling/axis primitives from the reproduction sweep: children over a
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
# (module sweep: multi-<return> sprocs were truncated to the first).
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
# rc stays 0 (the module sweep ran against un-created output dirs).
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

# --- 14: the getopt clone surface (S85) -------------------------------------
# Options.scaly wired into the CLI: clustered shorts, attached option args,
# unique-prefix long names, `--`, the ?/-/= error renderings, -h/-v, -t
# prefix matching + unknownType, empty -o, -d SYSID#ID selection, default
# output type fot + <docbase>.fot naming. Every shape reference-verified
# against the reference dazzle 2026-07-30 (probe battery).
base14="$(cd "$HERE" && SCALY_HOME="$ROOT" "$OUT" -t sgml -d map.dsl doc.sgml 2>/dev/null)"
for form in "-tsgml -d map.dsl doc.sgml" "-t s -d map.dsl doc.sgml" \
            "-dmap.dsl -t sgml doc.sgml" "-t sgml -d map.dsl -- doc.sgml"; do
  # shellcheck disable=SC2086
  got14="$(cd "$HERE" && SCALY_HOME="$ROOT" "$OUT" $form 2>/dev/null)"
  if [ "$got14" != "$base14" ]; then
    echo "dazzle-cli: FAIL getopt form ($form)"
    echo "  want: $(printf '%s' "$base14" | cat -v)"
    echo "  got:  $(printf '%s' "$got14" | cat -v)"
    exit 1
  fi
done

check_err() { # name rc want-rc errfile expected-lines...
  local name="$1" rc="$2" wantrc="$3" errf="$4"; shift 4
  local err; err="$(sed "s|^$OUT|PROG|" "$errf")"
  local want; want="$(printf '%s\n' "$@")"
  if [ "$rc" -ne "$wantrc" ] || [ "$err" != "$want" ]; then
    echo "dazzle-cli: FAIL $name (rc=$rc)"
    echo "  want: $(printf '%s' "$want" | cat -v)"
    echo "  err:  $(printf '%s' "$err" | cat -v)"
    exit 1
  fi
}

"$OUT" -Q 2>"$OUT.qerr" >/dev/null </dev/null; rc14=$?
check_err "getopt invalid option" "$rc14" 1 "$OUT.qerr" \
  'PROG:E: invalid option "Q"' \
  'PROG:I: Try the "--help" option for more information.'

"$OUT" --cat x 2>"$OUT.aerr" >/dev/null </dev/null; rc14=$?
check_err "getopt ambiguous long" "$rc14" 1 "$OUT.aerr" \
  'PROG:E: option "cat" is ambiguous' \
  'PROG:I: Try the "--help" option for more information.'

"$OUT" --version=x 2>"$OUT.eerr" >/dev/null </dev/null; rc14=$?
check_err "getopt erroneous arg" "$rc14" 1 "$OUT.eerr" \
  'PROG:E: option "version" doesn'"'"'t allow an argument' \
  'PROG:I: Try the "--help" option for more information.'

"$OUT" -d map.dsl -t 2>"$OUT.merr" >/dev/null </dev/null; rc14=$?
check_err "getopt missing option arg" "$rc14" 1 "$OUT.merr" \
  'PROG:E: invalid option "t"' \
  'PROG:I: Try the "--help" option for more information.'

got14="$("$OUT" --help </dev/null | sed "s|$OUT|PROG|")"
rc14=$?
want14="$(cat "$HERE/getopt-help.expected")"
if [ "$rc14" -ne 0 ] || [ "$got14" != "$want14" ]; then
  echo "dazzle-cli: FAIL getopt --help (rc=$rc14)"
  diff <(printf '%s\n' "$want14") <(printf '%s\n' "$got14") | head -6
  exit 1
fi

# -v: the openjade + OpenSP banners on stderr, the run continues.
got14="$(cd "$HERE" && SCALY_HOME="$ROOT" "$OUT" -v -t sgml -d map.dsl doc.sgml 2>"$OUT.verr")"
rc14=$?
err14="$(sed "s|^$OUT|PROG|" "$OUT.verr")"
wanterr14="$(printf '%s\n' 'PROG:I: "openjade" version "1.3.3-pre1"' 'PROG:I: "OpenSP" version "1.5.2"')"
if [ "$rc14" -ne 0 ] || [ "$got14" != "$base14" ] || [ "$err14" != "$wanterr14" ]; then
  echo "dazzle-cli: FAIL getopt -v (rc=$rc14)"
  echo "  err:  $(printf '%s' "$err14" | cat -v)"
  exit 1
fi

# file-creating shapes run in a scratch workdir: default type is fot with
# <docbase>.fot naming; an unknown -t reports and falls back to the default;
# an empty -o reports and the default name applies.
W14="$(mktemp -d)"
cp "$HERE/map.dsl" "$HERE/doc.sgml" "$W14/"
( cd "$W14" && SCALY_HOME="$ROOT" "$OUT" -d map.dsl doc.sgml >/dev/null 2>defterr </dev/null; echo $? > rc )
if [ "$(cat "$W14/rc")" -ne 0 ] || [ ! -s "$W14/doc.fot" ]; then
  echo "dazzle-cli: FAIL getopt default type fot"
  ls "$W14"; exit 1
fi
rm -f "$W14/doc.fot"
( cd "$W14" && SCALY_HOME="$ROOT" "$OUT" -t bogus -d map.dsl doc.sgml >/dev/null 2>bogerr </dev/null; echo $? > rc )
err14="$(sed "s|^$OUT|PROG|" "$W14/bogerr" | head -1)"
if [ "$(cat "$W14/rc")" -ne 0 ] || [ ! -s "$W14/doc.fot" ] \
   || [ "$err14" != 'PROG:E: unknown output type "bogus"' ]; then
  echo "dazzle-cli: FAIL getopt unknown type (err: $err14)"
  exit 1
fi
rm -f "$W14/doc.fot"
( cd "$W14" && SCALY_HOME="$ROOT" "$OUT" -t fot -d map.dsl -o '' doc.sgml >/dev/null 2>emperr </dev/null; echo $? > rc )
err14="$(sed "s|^$OUT|PROG|" "$W14/emperr" | head -1)"
if [ "$(cat "$W14/rc")" -ne 0 ] || [ ! -s "$W14/doc.fot" ] \
   || [ "$err14" != 'PROG:E: empty output filename' ]; then
  echo "dazzle-cli: FAIL getopt empty -o (err: $err14)"
  exit 1
fi
rm -rf "$W14"

# -d SYSID#ID: selects the style-specification with that (upcased) ID; a
# missing ID reports noStyleSpec and processes with no rules (rc 0).
got14="$(cd "$HERE" && SCALY_HOME="$ROOT" "$OUT" -t sgml -d wrapped.dsl#main suite.sgml 2>/dev/null)"
rc14=$?
if [ "$rc14" -ne 0 ] || [ "$got14" != "$want3" ]; then
  echo "dazzle-cli: FAIL getopt -d#ID (rc=$rc14, got: $got14)"
  exit 1
fi
got14="$(cd "$HERE" && SCALY_HOME="$ROOT" "$OUT" -t sgml -d wrapped.dsl#nosuch suite.sgml 2>"$OUT.iderr")"
rc14=$?
err14="$(sed "s|^$OUT|PROG|" "$OUT.iderr")"
if [ "$rc14" -ne 0 ] || [ "$got14" != "abc" ] \
   || [ "$err14" != 'PROG:E: no style-specification or external-specification with ID "NOSUCH"' ]; then
  echo "dazzle-cli: FAIL getopt -d#ID notfound (rc=$rc14, err: $err14)"
  exit 1
fi

# a multi-file document merges into ONE entity (the last file names the
# default output base — covered by the reference probes; here: same stdout).
W14="$(mktemp -d)"
cp "$HERE/map.dsl" "$W14/"
head -c 60 "$HERE/doc.sgml" > "$W14/d1.part"
tail -c +61 "$HERE/doc.sgml" > "$W14/d2.part"
got14="$(cd "$W14" && SCALY_HOME="$ROOT" "$OUT" -t sgml -d map.dsl d1.part d2.part 2>/dev/null)"
rc14=$?
if [ "$rc14" -ne 0 ] || [ "$got14" != "$base14" ]; then
  echo "dazzle-cli: FAIL getopt multi-file merge (rc=$rc14)"
  echo "  want: $(printf '%s' "$base14" | cat -v)"
  echo "  got:  $(printf '%s' "$got14" | cat -v)"
  exit 1
fi
rm -rf "$W14"

# The program carries its DSSSL prolog and the catalog with the DTDs that read
# a stylesheet (dazzle/DssslData.scaly, generated by tools/dssslgen.py): from an
# EMPTY directory, without SCALY_HOME and with a home of its own, the prolog
# (ids.dsl: map, node-list->list) and a stylesheet named by PUBLIC identifier
# (public.dsl) answer as they do in the tree -- before 2026-10-06 the prolog
# was silently missing there. And the generated module is what dsssl/ gives.
WE="$(mktemp -d)"
gotE1="$(cd "$WE" && env -u SCALY_HOME HOME="$WE/home" USERPROFILE="$WE/home" "$OUT" -t sgml -d "$HERE/ids.dsl" "$HERE/suite.sgml" 2>"$WE/e1.err")"; rcE1=$?
gotE2="$(cd "$WE" && env -u SCALY_HOME HOME="$WE/home" USERPROFILE="$WE/home" "$OUT" -t sgml -d "$HERE/public.dsl" "$HERE/suite.sgml" 2>"$WE/e2.err")"; rcE2=$?
wantE2="$(SCALY_HOME="$ROOT" "$OUT" -t sgml -d "$HERE/public.dsl" "$HERE/suite.sgml")"
if [ "$rcE1" -ne 0 ] || [ "$gotE1" != "$want2" ] || [ "$rcE2" -ne 0 ] || [ "$gotE2" != "$wantE2" ] || [ -z "$gotE2" ] \
   || [ ! -f "$(ls -d "$WE"/home/.cache/dazzle/dsssl-*/ | head -1)catalog" ]; then
  echo "dazzle-cli: FAIL own data, away from the tree (rc=$rcE1/$rcE2)"
  head -3 "$WE/e1.err" "$WE/e2.err"
  exit 1
fi
rm -rf "$WE"
if ! python3 "$ROOT/tools/dssslgen.py" --check > /dev/null; then
  echo "dazzle-cli: FAIL (dazzle/DssslData.scaly is not what dsssl/ gives -- run tools/dssslgen.py)"
  exit 1
fi

# MS-DOS file names (the reference's SP_MSDOS_FILENAMES, asked at run time:
# SP_FILENAMES, else the system): a stylesheet named with backslashes pulls
# in the entity beside it, the catalog list is separated by `;` and its
# entries by backslashes, the document lies under a backslash path -- the way
# a Windows batch file calls the program. Read as POSIX names the same call
# does not find the stylesheet's entity and answers with the document's text
# alone, at rc 0; that is the negative control.
WM="$(mktemp -d)"
mkdir -p "$WM/XMLModel/generator" "$WM/XMLModel/dsssl" "$WM/sub" "$WM/home"
cp "$HERE/msdos/gen/map.dsl" "$HERE/msdos/gen/rules.scm" "$WM/XMLModel/generator/"
cp "$ROOT"/packages/dazzle/0.1.0/dsssl/* "$WM/XMLModel/dsssl/"
cp "$HERE/msdos/doc.sgml" "$WM/sub/"
msdos_run() { ( cd "$WM" && env -u SCALY_HOME HOME="$WM/home" USERPROFILE="$WM/home" SP_FILENAMES="$1" \
  'SGML_CATALOG_FILES=nosuch\catalog;XMLModel\dsssl\catalog' "$OUT" -t sgml -d 'XMLModel\generator\map.dsl' 'sub\doc.sgml' 2>"$WM/$1.err" ); }
gotM="$(msdos_run msdos)"
gotP="$(msdos_run posix)"
if [ "$gotM" != "from!rules!" ] || [ "$gotP" = "from!rules!" ] || ! grep -q 'cannot open "nosuch/catalog"' "$WM/msdos.err"; then
  echo "dazzle-cli: FAIL MS-DOS file names"
  echo "  msdos: $(printf '%s' "$gotM" | cat -v) / $(head -2 "$WM/msdos.err" | cut -c1-160)"
  echo "  posix: $(printf '%s' "$gotP" | cat -v)"
  exit 1
fi
rm -rf "$WM"

echo "dazzle-cli: PASS"
