#!/usr/bin/env bash
# tests/dazzle/primprof/aggregate.sh — run a DZ_PRIM_PROF binary N times and
# sum the per-primitive tables into one ranking.
#
#   aggregate.sh <n-runs> <usec> <cwd> -- <command...>
#
# The BYTE column is exact and needs no aggregation for significance — one run
# already gives it in full. Summing runs is for the SAMPLED column, which at
# the 1 ms default yields ~500 samples per styling run and ranks three rows.
# Both are summed here so the two can be read side by side; the ranking is by
# bytes, because that is the column that holds still (see README, "Die
# Eichung": the sampler over-weights allocating code by ~an order of
# magnitude).
set -u
N="$1"; USEC="$2"; DIR="$3"; shift 3; [ "${1:-}" = "--" ] && shift

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for i in $(seq 1 "$N"); do
  ( cd "$DIR" && DZ_PRIM_PROF=1 DZ_PRIM_PROF_USEC="$USEC" "$@" ) \
     >/dev/null 2>>"$TMP/all.log" || { echo "aggregate: FAIL (run $i)"; exit 1; }
done

grep -q "STACK UNBALANCED" "$TMP/all.log" && \
  echo "aggregate: ★the byte column is INVALID — see the unbalanced-stack line"

awk -v n="$N" -v usec="$USEC" '
  /^primprof: [0-9]+ primitive calls/ { calls += $2; bytes += $5; crossed += $8; next }
  /^primprof: [0-9]+ samples/         { tot += $2; next }
  /^primprof: +[0-9.]+%/ {
      # bytes% bytes B/call calls cpu%~ samples crossed name...
      key = ""; for (i = 9; i <= NF; i++) key = key (i > 9 ? " " : "") $i
      B[key] += $3; C[key] += $5; S[key] += $7; X[key] += $8; seen[key] = 1
  }
  END {
      printf "primprof-agg: %d runs, %d primitive calls, %.1f MB self-allocated, %d page-crossing (%.2f %%)\n",
             n, calls, bytes/1048576.0, crossed, calls ? 100.0*crossed/calls : 0
      printf "primprof-agg: %d samples at %d us — the cpu%% column is BIASED, rank by bytes\n", tot, usec
      printf "primprof-agg: %7s %12s %9s %14s %8s %9s  %s\n",
             "bytes%", "MB", "B/call", "calls", "cpu%~", "crossed", "primitive"
      for (k in seen) {
          bp   = bytes ? 100.0 * B[k] / bytes : 0
          pct  = tot   ? 100.0 * S[k] / tot   : 0
          bpc  = C[k]  ? B[k] / C[k] : 0
          printf "%012.5f\tprimprof-agg: %6.2f%% %12.1f %9.1f %14d %7.2f%% %9d  %s\n",
                 bp, bp, B[k]/1048576.0, bpc, C[k], pct, X[k], k
      }
  }
' "$TMP/all.log" > "$TMP/out"

grep '^primprof-agg: ' "$TMP/out"
grep -v '^primprof-agg: ' "$TMP/out" | sort -r | cut -f2-
