#!/usr/bin/env bash
# tests/dazzle/jit/run.sh — the Stage-6b JIT gate.
#
#   tests/dazzle/jit/run.sh [scalyc-binary]
#
# Three things are checked, and each of them can fail:
#
#   1. THE CHAIN. `dazzle --jit-selftest` builds an LLVM module, JITs it, calls
#      it, and lets the generated code call back into the binary through an
#      inttoptr constant; it also re-runs the VM layout probe. A JIT that never
#      executed a module is the failure mode this exists to exclude.
#
#   2. BYTE-IDENTITY UNDER THE CODE GENERATOR. Every case here is run with the
#      JIT ON and with it OFF, and BOTH runs are compared against the SAME
#      golden — the goldens of the sibling suites, minted from the reference
#      C++ dazzle. Comparing the two modes to each other would pass if both
#      were wrong in the same way; comparing both to the reference cannot.
#      DAZZLE_JIT_THRESHOLD=1 makes every code body compile on FIRST entry, so
#      the code generator is exercised to the maximum instead of at whatever
#      coverage a HotSpot threshold happens to give.
#
#   3. COVERAGE. `--jit-stats` must report regions compiled, insns lowered, and
#      ZERO rejected bodies. A code generator that quietly compiled nothing
#      would otherwise pass check 2 perfectly.
#
# Why the JIT is not the default (and why this suite says so): measured
# 2026-08-06 the compiled path is byte-identical and SLOWER — see the Stage-6b
# section of tests/dazzle/PERFORMANCE.md. The gate is here so the code generator
# stays correct while the two measured rungs (per-module LLVM cost, native
# lowering of the call/return/primitive arms) are worked off.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "dazzle-jit: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

# --- 1. the chain ----------------------------------------------------------
if ! "$OUT" --jit-selftest > "$WORK/selftest.log" 2>&1; then
  echo "dazzle-jit: FAIL (selftest)"; cat "$WORK/selftest.log"; exit 1
fi

# The selftest must also FAIL when it should: a JIT that cannot come up has to
# say so rather than report OK. Proved by pointing the pass pipeline at a
# nonexistent pass — the JIT keeps working (the pipeline is best-effort), so
# this checks the reporting path, not the pipeline.
if ! DAZZLE_JIT_PIPELINE="no-such-pass-name" "$OUT" --jit-selftest > "$WORK/selftest2.log" 2>&1; then
  echo "dazzle-jit: FAIL (selftest under a broken pipeline)"; cat "$WORK/selftest2.log"; exit 1
fi

# --- 2. byte-identity, both modes, against the reference goldens -----------
ENGINE="$ROOT/tests/dazzle/engine"
PRIMS="$ROOT/tests/dazzle/prims"
cp "$ENGINE"/*.sgml "$ENGINE"/*.dsl "$WORK/" 2>/dev/null
cp "$PRIMS"/*.sgml "$PRIMS"/*.dsl "$WORK/" 2>/dev/null

fail=0
cases=0

run_mode() { # name goldendir expected_err flag dsl doc mode
  local name="$1" gdir="$2" experr="$3" flag="$4" dsl="$5" doc="$6" mode="$7"
  local env_jit=""
  if [ "$mode" = jit ]; then env_jit="1"; fi
  ( cd "$WORK" && SCALY_HOME="$ROOT" DAZZLE_JIT="${env_jit:-0}" DAZZLE_JIT_THRESHOLD=1 \
      "$OUT" $flag -t sgml -d "$dsl.dsl" "$doc" > "$name.$mode.out" 2> "$name.$mode.err" )
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-jit: FAIL $name ($mode: rc=$rc)"; cat "$WORK/$name.$mode.err"; return 1
  fi
  if ! diff -q "$gdir/$name.expected" "$WORK/$name.$mode.out" > /dev/null; then
    echo "dazzle-jit: FAIL $name ($mode: stdout differs from the reference golden)"
    diff "$gdir/$name.expected" "$WORK/$name.$mode.out" | head -10
    return 1
  fi
  sed 's/^[^:]*:/PROG:/' "$WORK/$name.$mode.err" > "$WORK/$name.$mode.err.norm"
  if ! diff -q "$gdir/$experr" "$WORK/$name.$mode.err.norm" > /dev/null; then
    echo "dazzle-jit: FAIL $name ($mode: stderr differs from the reference golden)"
    diff "$gdir/$experr" "$WORK/$name.$mode.err.norm" | head -10
    return 1
  fi
  return 0
}

run_case() { # name goldendir expected_err flag dsl doc
  local name="$1"
  cases=$((cases + 1))
  run_mode "$@" interp || { fail=1; return; }
  run_mode "$@" jit    || { fail=1; return; }
  # and the two modes agree byte-for-byte with each other, which is the
  # statement the differential is named for
  if ! cmp -s "$WORK/$name.interp.out" "$WORK/$name.jit.out"; then
    echo "dazzle-jit: FAIL $name (interp and jit disagree)"; fail=1
  fi
}

#            name    golden dir  expected-err     flag  stylesheet  document
run_case key1  "$ENGINE" key1.experr  ""   key1  keydoc.sgml
run_case key2  "$ENGINE" key2.experr  "-2" key2  keydoc.sgml
run_case key3  "$ENGINE" key3.experr  ""   key3  keydoc.sgml
run_case prop1 "$ENGINE" prop1.experr ""   prop1 propdoc.sgml
run_case pat1  "$ENGINE" pat1.experr  ""   pat1  patdoc.sgml
run_case pat2  "$ENGINE" pat2.experr  "-2" pat2  patdoc.sgml
run_case query1 "$ENGINE" query1.experr "" query1 patdoc.sgml

# --- 3. coverage -----------------------------------------------------------
( cd "$WORK" && SCALY_HOME="$ROOT" DAZZLE_JIT=1 DAZZLE_JIT_THRESHOLD=1 \
    "$OUT" --jit-stats -t sgml -d pat1.dsl patdoc.sgml > /dev/null 2> stats.err )
STATS="$(grep 'dazzle JIT:' "$WORK/stats.err" | tail -1)"
if [ -z "$STATS" ]; then
  echo "dazzle-jit: FAIL (--jit-stats reported nothing)"; exit 1
fi
REGIONS="$(echo "$STATS" | sed 's/.*JIT: \([0-9]*\) regions.*/\1/')"
NATIVE="$(echo "$STATS" | sed 's/.*(\([0-9]*\) native.*/\1/')"
REJECTED="$(echo "$STATS" | sed 's/.*, \([0-9]*\) rejected roots.*/\1/')"
if [ "${REGIONS:-0}" -lt 1 ]; then
  echo "dazzle-jit: FAIL (no region was compiled: $STATS)"; exit 1
fi
if [ "${NATIVE:-0}" -lt 1 ]; then
  echo "dazzle-jit: FAIL (no insn was lowered natively: $STATS)"; exit 1
fi
if [ "${REJECTED:-1}" -ne 0 ]; then
  echo "dazzle-jit: FAIL (a body was rejected by the code generator: $STATS)"; exit 1
fi

if [ "$fail" -ne 0 ]; then
  echo "dazzle-jit: FAIL"; exit 1
fi
echo "dazzle-jit: PASS ($cases cases in both modes; $REGIONS regions, $NATIVE insns native, 0 rejected)"
