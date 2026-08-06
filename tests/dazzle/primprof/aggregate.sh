#!/usr/bin/env bash
# tests/dazzle/primprof/aggregate.sh — run a DZ_PRIM_PROF binary N times and
# sum the per-primitive tables into one ranking.
#
#   aggregate.sh <n-runs> <usec> <cwd> -- <command...>
#
# One run of the styling workload yields ~500 samples at the 1 ms default,
# which ranks the top three and nothing below them. Summing N runs at a finer
# period is the cheap way to a ranking that holds still: the estimator is
# unbiased per run, so the sum is the same profile with N times the samples.
# The ns/call column is recomputed from the summed samples and calls.
set -u
N="$1"; USEC="$2"; DIR="$3"; shift 3; [ "${1:-}" = "--" ] && shift

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for i in $(seq 1 "$N"); do
  ( cd "$DIR" && DZ_PRIM_PROF=1 DZ_PRIM_PROF_USEC="$USEC" "$@" ) \
     >/dev/null 2>>"$TMP/all.log" || { echo "aggregate: FAIL (run $i)"; exit 1; }
done

awk -v n="$N" -v usec="$USEC" '
  /^primprof: *[0-9]+ samples/ { tot += $2; calls += $4; next }
  /^primprof: +[0-9.]+%/ {
      key = ""; for (i = 6; i <= NF; i++) key = key (i > 6 ? " " : "") $i
      S[key] += $3; C[key] += $4; seen[key] = 1
  }
  END {
      printf "primprof-agg: %d runs at %d us -> %d samples, %d primitive calls\n", n, usec, tot, calls
      printf "primprof-agg: %8s %11s %14s %9s  %s\n", "cpu%", "samples", "calls", "ns/call", "primitive"
      for (k in seen) {
          pct  = tot  ? 100.0 * S[k] / tot : 0
          nspc = C[k] ? S[k] * usec * 1000.0 / C[k] : 0
          printf "%012.5f\tprimprof-agg: %7.3f%% %11d %14d %9.1f  %s\n", pct, pct, S[k], C[k], nspc, k
      }
  }
' "$TMP/all.log" > "$TMP/out"

grep '^primprof-agg: ' "$TMP/out"
grep -v '^primprof-agg: ' "$TMP/out" | sort -r | cut -f2-
