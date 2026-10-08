#!/usr/bin/env bash
# tests/run.sh — every suite of the port, one line each.
#
#   tests/run.sh [scalyc-binary]     (default: tests/toolchain.sh — the
#                                     installed scalyc, or SCALYC)
#
# Needs this checkout and an installed Scaly (https://scaly.io), nothing else:
# the compiler finds the standard library in its installation and the packages
# opensp and dazzle in ./packages. The goldens are committed; the C++ reference
# programs are only needed to re-bless them.
#
# What runs, in this order:
#
#   dazzle-build   the engine, ONCE (tests/dazzle/build-cli.sh); every dazzle
#                  suite gets it as DAZZLE_PREBUILT
#   dazzle-<d>     the engine's suites, side by side: cli coding engine flowobj
#                  fot framemark grove html mif pdf prims rtf specarena tex
#   dazzle-unit    the engine's self-tests (tests/dazzle/run.sh, `scaly test`)
#   onsgmls-build  the parser's event dumper (tests/sgml/build-onsgmls.sh)
#   sgml           the SGML corpus against it (tests/sgml/run.sh)
#   opensp         the parser's self-tests (tests/opensp/run.sh, `scaly test`)
#   cmscratch      the content-model scratch arena (tests/sgml/cmscratch/run.sh)
#   quiet          onsgmls -s: no ESIS, the same messages (tests/sgml/quiet/run.sh)
#
# The dazzle suites and the corpus run under SCALY_POISON=1: every released
# page is overwritten, so a read after release faults at its first use instead
# of passing by luck.
#
# Exit status 0 when every suite passed. A failed suite's log stays in the
# directory named at the end; everything else is removed.
#
# Not run here, each for its reason: tests/dazzle/nsweep, perf-survey.sh,
# and memhw.sh are instruments (they measure, minutes of it); tests/sgml/coding
# and the two deviation scripts compare with the C++ reference programs.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
. tests/toolchain.sh "${1:-}" || exit 2
# shellcheck disable=SC1091
. tests/platform.sh || exit 1
set -u

# compiling packages/dazzle recurses deeper than the default 8 MB stack holds
ulimit -s 65520 2>/dev/null || echo "tests/run.sh: could not raise the stack limit to 64 MB — the dazzle build may fail"

LOG="$(mktemp -d)"
rc=0
failed=""

# step <name> <command…>: run it, print `<name>: <its last line>`
step() {
  local name="$1"; shift
  if "$@" > "$LOG/$name.log" 2>&1; then
    echo "$name: $(tail -1 "$LOG/$name.log" | cut -c1-100)"
    return 0
  fi
  echo "$name: FAIL — $LOG/$name.log"
  failed="$failed $name"
  rc=1
  return 1
}

DAZZLE_SUITES="cli coding engine flowobj fot framemark grove html mif pdf prims rtf specarena tex"

if step dazzle-build env DAZZLE_PREBUILT= tests/dazzle/build-cli.sh "$LOG/dazzle"; then
  pids=(); names=()
  for d in $DAZZLE_SUITES; do
    ( DAZZLE_PREBUILT="$LOG/dazzle" SCALY_POISON=1 "tests/dazzle/$d/run.sh" > "$LOG/dazzle-$d.log" 2>&1 ) &
    pids+=($!); names+=("$d")
  done
  for i in "${!pids[@]}"; do
    n="dazzle-${names[$i]}"
    if wait "${pids[$i]}"; then
      echo "$n: $(tail -1 "$LOG/$n.log" | cut -c1-100)"
    else
      echo "$n: FAIL — $LOG/$n.log"; failed="$failed $n"; rc=1
    fi
  done
fi
step dazzle-unit tests/dazzle/run.sh

if step onsgmls-build tests/sgml/build-onsgmls.sh "$LOG/onsgmls"; then
  # On a Windows shell $LOG/onsgmls is a bash front end over
  # tests/win32/lf-wrapper.sh; the corpus driver starts the native binary
  # itself (its streams are binary, there is no CR to strip), which costs one
  # process per model instead of a shell.
  sgml_bin="$LOG/onsgmls"
  [ -f "$LOG/onsgmls-native.exe" ] && sgml_bin="$LOG/onsgmls-native.exe"
  step sgml env SCALY_POISON=1 tests/sgml/run.sh "$sgml_bin"
  step opensp tests/opensp/run.sh
  step cmscratch tests/sgml/cmscratch/run.sh "$LOG/onsgmls"
  step quiet tests/sgml/quiet/run.sh "$LOG/onsgmls"
else
  step opensp tests/opensp/run.sh
fi

if [ $rc = 0 ]; then
  rm -rf "$LOG"
  echo "tests: all suites PASS"
else
  rm -f "$LOG/dazzle" "$LOG/dazzle-native.exe" "$LOG/onsgmls" "$LOG/onsgmls-native.exe"
  echo "tests: FAIL —$failed (logs in $LOG)"
fi
exit $rc
