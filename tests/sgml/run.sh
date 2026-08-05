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
# ★The count is GATED (see the discovery gate at the bottom): the number of
# models found must equal `expected-models` — the public tier's is committed, the
# private tier's is written by fetch/freeze. A number nobody checks is a number
# that drifts: "469/469" was quoted in PERFORMANCE.md at nine places while the
# suite was reporting 462, and the reverse failure (a tier that silently stops
# being discovered, so M shrinks and N/M still reads "all green") had nothing
# watching it at all. Both directions fail here.
#
# Per-entry layout: a directory with a `manifest` and golden `expected.esis` +
# `expected.exit`. The manifest is sourced and may set:
#   DOC=<file>            document passed to the binary (required)
#   BASE=repo|entry       resolve DOC/cwd against repo root or the entry dir
#                         (default: entry — self-contained fixture)
#   WORKDIR=<path>        cwd override (wins over BASE). ABSOLUTE: the model
#                         stays in its home repo and no local source is
#                         copied into this tree. RELATIVE: resolved against the
#                         entry — a FROZEN private entry (freeze-private.sh)
#                         carrying its own copy, so the corpus stops drifting
#                         when those repos move on
#   SP_ENV="K=V K=V"      environment prefix (e.g. SP_CHARSET_FIXED=YES SP_ENCODING=XML)
#   EXTRA_ARGS="..."      extra args before DOC (e.g. a leading xml.dcl, -c catalog)
#   RAST=1                run with -t <tmpfile> and compare it against the
#                         entry's expected.rast golden (the -t RAST axis)

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
pub_seen=0; priv_seen=0
for entry in "$HERE"/corpus/*/ "$HERE"/corpus-private/*/; do
  [ -f "$entry/manifest" ] || continue
  name="$(basename "$entry")"
  # Count what EXISTS before the filter, so the discovery gate below judges the
  # corpus and not the selection.
  case "$entry" in
    "$HERE"/corpus-private/*) priv_seen=$((priv_seen + 1)) ;;
    *)                        pub_seen=$((pub_seen + 1)) ;;
  esac
  case "$name" in $FILTER) ;; *) continue ;; esac

  DOC=""; BASE="entry"; SP_ENV=""; EXTRA_ARGS=""; WORKDIR=""; RAST=0
  # shellcheck disable=SC1091
  . "$entry/manifest"
  [ -n "$DOC" ] || { echo "  $name: manifest missing DOC" >&2; continue; }

  if [ -n "$WORKDIR" ]; then
    # A RELATIVE WORKDIR resolves against the entry — that is how a frozen
    # private entry names the subdirectory holding its own copy of the model
    # (freeze-private.sh writes `WORKDIR=frozen`). The doc sits one level down
    # so a system identifier reaching upwards (`../x/y.dtd`) still lands inside
    # the entry. An ABSOLUTE WORKDIR keeps its old meaning: the model stays in
    # its home repo and nothing local is copied here.
    case "$WORKDIR" in
      /*) workdir="$WORKDIR" ;;
      *)  workdir="$entry/$WORKDIR" ;;
    esac
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
  got_rast="$TMP/$name.rast"; rm -f "$got_rast"
  RAST_ARGS=""
  [ "$RAST" = "1" ] && RAST_ARGS="-t $got_rast"
  ( cd "$workdir" && env $SP_ENV "$BIN" $RAST_ARGS $EXTRA_ARGS "$DOC" ) \
    >"$got_esis" 2>"$TMP/$name.err"
  echo $? >"$got_exit"

  norm_err <"$TMP/$name.err" >"$TMP/$name.err.norm"

  if [ "$BLESS" -eq 1 ]; then
    cp "$got_esis" "$entry/expected.esis"
    cp "$got_exit" "$entry/expected.exit"
    cp "$TMP/$name.err.norm" "$entry/expected.err"
    [ "$RAST" = "1" ] && cp "$got_rast" "$entry/expected.rast"
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
  rast_ok=1
  if [ "$RAST" = "1" ]; then
    diff -q "$entry/expected.rast" "$got_rast" >/dev/null 2>&1 || rast_ok=0
  fi
  if diff -q "$entry/expected.esis" "$got_esis" >/dev/null 2>&1 \
     && [ "$(cat "$entry/expected.exit" 2>/dev/null)" = "$(cat "$got_exit")" ] \
     && [ "$err_ok" -eq 1 ] && [ "$rast_ok" -eq 1 ]; then
    ok=$((ok+1))
  else
    failed="$failed $name"
    reason="exit want=$(cat "$entry/expected.exit" 2>/dev/null) got=$(cat "$got_exit")"
    [ "$err_ok" -eq 0 ] && reason="$reason; stderr differs"
    [ "$rast_ok" -eq 0 ] && reason="$reason; rast differs"
    echo "  MISMATCH $name ($reason)"
  fi
done

# --- stdin fidelity check (S85) ---------------------------------------------
# A stdin document (`<OSFD>0`, no inheritable storage object) consults NO
# implicit `catalog` — the port used to read the CWD's catalog, so a stray
# cwd catalog's SGMLDECL (this repo's `catalog` -> scaly.dcl) silently
# re-declared stdin parses (namecase off, reserved names rejected). Run from
# the repo root, where exactly that catalog exists; expect the reference
# concrete syntax (upcased GIs, `o o` minimization accepted). Golden verified
# against real onsgmls 1.5.2.
stdin_got="$(cd "$REPO_ROOT" && printf '<!DOCTYPE a [\n<!ELEMENT a o o (#pcdata)>\n]>\n<a>hi</a>\n' | "$BIN" 2>&1)"
stdin_rc=$?
stdin_want="$(printf '(A\n-hi\n)A\nC')"
if [ "$stdin_rc" -ne 0 ] || [ "$stdin_got" != "$stdin_want" ]; then
  echo "  MISMATCH stdin-no-doc-catalog (rc=$stdin_rc)"
  printf '%s\n' "$stdin_got" | head -4
  failed="$failed stdin-no-doc-catalog"
fi

echo

# --- the DISCOVERY gate ------------------------------------------------------
# "N of M ESIS-identical" only means something if M is the corpus we expect. A
# shrinking M is invisible in that line — a renamed directory, a manifest that
# lost its DOC, an unfetched private tier, and the suite happily reports
# "366 of 366" with rc 0 while a hundred models silently stopped running. So the
# expected count is written down and compared in BOTH directions: fewer is a
# corpus that fell out, more is a corpus that grew, and both must be a deliberate
# edit of the file rather than a number nobody reads.
#
# The public tier is committed, so its count is committed too. The private tier is
# gitignored and optional (CI has none): its expectation lives in the tier itself,
# written by fetch/freeze, and is only checked when the tier is present.
#
# Skipped under --filter: a filtered run is a selection, not a corpus.
gate_rc=0
if [ "$FILTER" = '*' ]; then
  pub_want_file="$HERE/expected-models"
  if [ -f "$pub_want_file" ]; then
    pub_want="$(tr -dc '0-9' < "$pub_want_file")"
    if [ "$pub_seen" != "$pub_want" ]; then
      echo "  CORPUS public tier has $pub_seen models, expected $pub_want"
      echo "  (if that change is intended, edit tests/sgml/expected-models)"
      gate_rc=1
    fi
  else
    echo "  CORPUS no tests/sgml/expected-models — discovery is ungated"
    gate_rc=1
  fi
  priv_want_file="$HERE/corpus-private/expected-models"
  if [ -f "$priv_want_file" ]; then
    priv_want="$(tr -dc '0-9' < "$priv_want_file")"
    if [ "$priv_seen" != "$priv_want" ]; then
      echo "  CORPUS private tier has $priv_seen models, expected $priv_want"
      echo "  (if that change is intended, edit tests/sgml/corpus-private/expected-models)"
      gate_rc=1
    fi
  elif [ "$priv_seen" -gt 0 ]; then
    echo "  CORPUS private tier present ($priv_seen models) but not gated —"
    echo "  write the count to tests/sgml/corpus-private/expected-models"
  fi
fi

if [ "$BLESS" -eq 1 ]; then
  echo "blessed $ok of $total models"
else
  echo "$ok of $total models ESIS-identical"
  if [ -n "$failed" ]; then echo "failed:$failed"; exit 1; fi
fi
[ "$gate_rc" -eq 0 ] || exit 1
exit 0
