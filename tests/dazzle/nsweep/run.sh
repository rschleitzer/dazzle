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
# into a gate later, but tests/run.sh does not run it today: the sizes it needs
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
FILTER="${2:-}"
cd "$ROOT"
# shellcheck disable=SC1091
. tests/toolchain.sh "${1:-}" || exit 2

command -v python3 >/dev/null 2>&1 || { echo "nsweep: python3 is required"; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DZ="${DAZZLE_BIN:-}"
if [ -z "$DZ" ]; then
  DZ="$TMP/dazzle"
  if ! tests/dazzle/build-cli.sh "$DZ" > "$TMP/build.log" 2>&1; then
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
# ★Check WHICH engine answered, not just that one did. The baseline is the
# PORTING-SOURCE build, and whatever sits on PATH may be something else:
# Ubuntu 24.04 ships OpenJade 1.4devel, a different program. Comparing against
# it would still print a comparison, which is the bad outcome — a silently
# substituted oracle reads exactly like a correct one. Running WITHOUT a
# reference is the honest state and this script already supports it.
#
# ★Keyed on IDENTITY, not on one version string. The first version of this
# check pinned "1.3.3-pre1" and was wrong within the hour (2026-08-14): the
# porting source renamed itself, so the December build says
# `"openjade" version "1.3.3-pre1"` and a build from current source says
# `"dazzle" version "1.3.3"`, while the distribution says
# `"OpenJade" version "1.4devel"`. The name `dazzle` identifies the fork on its
# own; the historical spelling is admitted by its version.
# REF_JADE names a binary deliberately, NSWEEP_REF_VERSION admits a further one.
if [ -n "$REF" ]; then
  ref_id="$("$REF" -v < /dev/null 2>&1 \
            | sed -n 's/.*"\([^"]*\)" version "\([^"]*\)".*/\1 \2/p' | head -1)"
  ref_name="${ref_id% *}"; ref_ver="${ref_id#* }"
  if [ "$ref_name" != dazzle ] && [ "$ref_ver" != "1.3.3-pre1" ] \
     && { [ -z "${NSWEEP_REF_VERSION:-}" ] || [ "$ref_ver" != "$NSWEEP_REF_VERSION" ]; }; then
    echo "nsweep: reference \"$REF\" identifies as [${ref_id:-unknown}], not the" \
         "porting-source build — running without a reference."
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
