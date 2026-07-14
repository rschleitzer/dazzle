#!/usr/bin/env bash
# tests/sgml/run.sh — the dazzle/OpenSP corpus oracle.
#
# Replays the frozen SGML/XML corpus against a configurable onsgmls-compatible
# parser binary and diffs its ESIS output + exit code against the golden
# snapshots taken from the real onsgmls. Prints the running counter
#
#     N of M models ESIS-identical
#
# which is THE progress bar for Part I of the port (Stages 0-5). Run with the
# default binary (onsgmls) it must report M/M — proving the harness and the
# frozen goldens agree with the reference. Run against the Scaly onsgmls
# drop-in it reports the coverage that gates every following stage.
#
# Usage:
#   tests/sgml/run.sh [binary]          replay (default binary: onsgmls)
#   tests/sgml/run.sh --bless [binary]  regenerate goldens from binary (onsgmls)
#   tests/sgml/run.sh --filter <glob>   only entries whose name matches
#
# Two-tier corpus (see README.md):
#   corpus/          public, committed — Scaly's own SGML + synthetic fixtures
#   corpus-private/  gitignored further documents (fetch-private.sh)
#
# Per-entry layout: a directory with a `manifest` and golden `expected.esis` +
# `expected.exit`. The manifest is sourced and may set:
#   DOC=<file>            document passed to the binary (required)
#   BASE=repo|entry       resolve DOC/cwd against repo root or the entry dir
#                         (default: entry — self-contained fixture)
#   WORKDIR=<abs path>    absolute cwd override (wins over BASE) — used by the
#                         private tier to point at models in their home repos
#                         WITHOUT copying local source into this tree
#   SP_ENV="K=V K=V"      environment prefix (e.g. SP_CHARSET_FIXED=YES SP_ENCODING=XML)
#   EXTRA_ARGS="..."      extra args before DOC (e.g. a leading xml.dcl, -c catalog)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

BLESS=0
FILTER='*'
BIN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --bless) BLESS=1 ;;
    --filter) shift; FILTER="$1" ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) BIN="$1" ;;
  esac
  shift
done
[ -n "$BIN" ] || BIN="onsgmls"

if ! command -v "$BIN" >/dev/null 2>&1 && [ ! -x "$BIN" ]; then
  echo "binary not found: $BIN" >&2; exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Diagnostics on stderr are compared byte-for-byte EXCEPT the leading program
# name (MessageReporter's programName_, argv[0]) which differs between the real
# onsgmls and the Scaly drop-in. Strip everything up to the first colon (program
# paths carry no colon, and the filename that follows never does either).
norm_err() { sed 's/^[^:]*://'; }

total=0; ok=0; failed=""
for entry in "$HERE"/corpus/*/ "$HERE"/corpus-private/*/; do
  [ -f "$entry/manifest" ] || continue
  name="$(basename "$entry")"
  case "$name" in $FILTER) ;; *) continue ;; esac

  DOC=""; BASE="entry"; SP_ENV=""; EXTRA_ARGS=""; WORKDIR=""
  # shellcheck disable=SC1091
  . "$entry/manifest"
  [ -n "$DOC" ] || { echo "  $name: manifest missing DOC" >&2; continue; }

  if [ -n "$WORKDIR" ]; then
    workdir="$WORKDIR"
  else
    case "$BASE" in
      repo)  workdir="$REPO_ROOT" ;;
      entry) workdir="$entry" ;;
      *)     echo "  $name: bad BASE=$BASE" >&2; continue ;;
    esac
  fi
  if [ ! -d "$workdir" ]; then
    echo "  $name: workdir missing ($workdir) — skipped (fetch-private.sh?)"; continue
  fi

  got_esis="$TMP/$name.esis"; got_exit="$TMP/$name.exit"
  ( cd "$workdir" && env $SP_ENV "$BIN" $EXTRA_ARGS "$DOC" ) \
    >"$got_esis" 2>"$TMP/$name.err"
  echo $? >"$got_exit"

  norm_err <"$TMP/$name.err" >"$TMP/$name.err.norm"

  if [ "$BLESS" -eq 1 ]; then
    cp "$got_esis" "$entry/expected.esis"
    cp "$got_exit" "$entry/expected.exit"
    cp "$TMP/$name.err.norm" "$entry/expected.err"
    echo "  blessed $name"
    total=$((total+1)); ok=$((ok+1))
    continue
  fi

  total=$((total+1))
  if [ ! -f "$entry/expected.esis" ]; then
    echo "  $name: NO GOLDEN (run --bless)"; failed="$failed $name"; continue
  fi
  # stderr is compared (normalized) only where a golden exists — an entry without
  # expected.err stays backward-compatible (ESIS + exit only).
  err_ok=1
  if [ -f "$entry/expected.err" ]; then
    diff -q "$entry/expected.err" "$TMP/$name.err.norm" >/dev/null 2>&1 || err_ok=0
  fi
  if diff -q "$entry/expected.esis" "$got_esis" >/dev/null 2>&1 \
     && [ "$(cat "$entry/expected.exit" 2>/dev/null)" = "$(cat "$got_exit")" ] \
     && [ "$err_ok" -eq 1 ]; then
    ok=$((ok+1))
  else
    failed="$failed $name"
    reason="exit want=$(cat "$entry/expected.exit" 2>/dev/null) got=$(cat "$got_exit")"
    [ "$err_ok" -eq 0 ] && reason="$reason; stderr differs"
    echo "  MISMATCH $name ($reason)"
  fi
done

echo
if [ "$BLESS" -eq 1 ]; then
  echo "blessed $ok of $total models"
else
  echo "$ok of $total models ESIS-identical"
  if [ -n "$failed" ]; then echo "failed:$failed"; exit 1; fi
fi
exit 0
