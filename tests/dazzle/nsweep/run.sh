#!/usr/bin/env bash
# tests/dazzle/nsweep/run.sh — the COMPLEXITY screen: which primitives are
# quadratic in the width of a sibling group, and which of those the reference
# is quadratic in too.
#
#   tests/dazzle/nsweep/run.sh [scalyc-binary] [probe-filter]
#
# Environment:
#   DAZZLE_BIN   port CLI to measure     (default: build it into a temp dir)
#   REF_JADE     reference engine        (default: dazzle, else openjade; a
#                                         missing one degrades the run to
#                                         "quadratic yes/no" with a note)
#   NSWEEP_SIZES sibling counts          (default: "500 1000 2000 4000")
#   NSWEEP_MIXED 1 = alternate two GIs in the sibling group
#
# This is an INSTRUMENT, not a gate — like ../framevol and ../frameprobe. It
# reports numbers and exits 1 when it sees a port defect, so it can be wired
# into a gate later, but nothing in the bar runs it today: the sizes it needs
# make it a minute-scale run, and its answer is a ranking rather than a
# pass/fail.
#
# ★Why it exists. Four of the port's largest wins were all the same shape — the
# reference keeps an incremental structure that the port did not take over
# (NumberCache, the hashed id index, the lazy pair node-list, lazy
# select-elements). Every one of them was found by accident. This finds them on
# purpose: a quadratic shows up as the marginal cost growing 4x per doubling of
# N, and running the SAME probe against the reference is what separates a port
# defect from work that is inherently quadratic.
#
# ★And it is deliberately black-box. It writes documents and stylesheets and
# reads /usr/bin/time; it patches no engine source, so unlike framevol and
# frameprobe it cannot go stale against an internal rename.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
FILTER="${2:-}"
cd "$ROOT"

command -v python3 >/dev/null 2>&1 || { echo "nsweep: python3 is required"; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DZ="${DAZZLE_BIN:-}"
if [ -z "$DZ" ]; then
  DZ="$TMP/dazzle"
  if ! tests/dazzle/build-cli.sh "$DZ" "$BIN" > "$TMP/build.log" 2>&1; then
    echo "nsweep: FAIL (build)"; tail -8 "$TMP/build.log"; exit 1
  fi
fi

REF="${REF_JADE:-}"
if [ -z "$REF" ]; then
  # dazzle (openjade 1.3.3-pre1) is the porting source and therefore the right
  # baseline — the same choice perf-survey.sh makes, for the same reason.
  if command -v dazzle >/dev/null 2>&1; then REF=dazzle
  elif command -v openjade >/dev/null 2>&1; then REF=openjade
  fi
fi
if [ -n "$REF" ] && ! command -v "$REF" >/dev/null 2>&1; then
  echo "nsweep: REF_JADE=\"$REF\" is not executable — running without a reference."
  REF=""
fi
# ★Check WHICH openjade answered, not just that one did. The baseline above is
# a specific BUILD — 1.3.3-pre1 from the porting source — and the `openjade`
# fallback on PATH may be something else entirely: Ubuntu 24.04 ships OpenJade
# 1.4devel, a different program version. Comparing against it would still print
# a comparison, which is the bad outcome: a silently substituted oracle reads
# exactly like a correct one. Running WITHOUT a reference is the honest state
# and the script already supports it. REF_JADE names a binary deliberately;
# NSWEEP_REF_VERSION relaxes the expected version for it.
if [ -n "$REF" ]; then
  ref_want="${NSWEEP_REF_VERSION:-1.3.3-pre1}"
  ref_ver="$("$REF" -v < /dev/null 2>&1 | sed -n 's/.*version "\([^"]*\)".*/\1/p' | head -1)"
  if [ "$ref_ver" != "$ref_want" ]; then
    echo "nsweep: reference \"$REF\" reports version '${ref_ver:-unknown}', expected" \
         "$ref_want (the porting source) — running without a reference."
    REF=""
  fi
fi
if [ -z "$REF" ]; then
  echo "nsweep: no reference engine (dazzle/openjade) — the run can only say"
  echo "        'quadratic', not 'quadratic where the reference is not'."
fi

echo "nsweep: complexity screen"
echo "  port      : $DZ"
echo "  reference : ${REF:-<none>}"

python3 "$HERE/sweep.py" \
  --port "$DZ" --ref "$REF" --home "$ROOT" --workdir "$TMP" \
  --sizes "${NSWEEP_SIZES:-500 1000 2000 4000}" \
  ${FILTER:+--filter "$FILTER"} \
  ${NSWEEP_MIXED:+--mixed}
rc=$?
[ "$rc" = 1 ] && echo "
nsweep: rows marked PORT DEFECT are quadratic here and not in the reference.
        The two known causes and the order to fix them are in README.md."
exit $rc
