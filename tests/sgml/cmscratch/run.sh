#!/usr/bin/env bash
# tests/sgml/cmscratch/run.sh — gate for the CONTENT-MODEL COMPILE SCRATCH
# arena (opensp ContentToken, `SP_CM_SCRATCH`).
#
#   tests/sgml/cmscratch/run.sh [onsgmls-binary]
#     (default: builds one from the current tree)
#
# `ContentToken.compile` runs Clark's position-automaton construction. Its
# FIRST/LAST sets, their arrays, the per-member temporaries, GroupInfo and the
# min_buf/elem_buf tables `finish` scribbles on are all DEAD the moment compile
# returns — in the reference they are stack locals and a freed Vector<>, on a
# bump region they lived as long as the DTD. The seam puts them on an exclusive
# page chain and releases it. What survives (the CmNode graph, each leaf's
# follow arrays, the CompiledModelGroup) stays on `host` — a follow array grows
# through `Page.get(the Array)`, i.e. the node's own page, so it is unaffected
# by which page the analysis ran on.
#
# ★Three things are checked, and the third is the one that matters:
#
#   1. ESIS + stderr + exit code identical in BOTH modes over the DTD-heavy
#      fixtures. The DTD path is what the 469 ESIS models validate and a
#      content-model DFA decides validity, so identity is the whole licence.
#   2. The COUNTER says the seam engaged, and that it can fall: default mode
#      reports arenas > 0 / on-host 0, `SP_CM_SCRATCH=0` the reverse. A seam
#      whose absence is invisible in the output needs a counter as its
#      checksum, or a build that silently stopped scratching passes every
#      byte-identity gate (the lesson the switched-off escape gate cost once).
#   3. The MEMORY actually drops. A counter can be right while the release is
#      a no-op, so the gate measures peak RSS in both modes and requires the
#      scratch run to be strictly smaller. That is the only assertion here
#      that would notice a `deallocate_exclusive_page` that stopped freeing.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT"

BIN="${1:-}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ -z "$BIN" ]; then
  if ! tests/sgml/build-onsgmls.sh "$TMP/onsgmls" > "$TMP/build.log" 2>&1; then
    echo "cmscratch: FAIL (build)"; tail -12 "$TMP/build.log"; exit 1
  fi
  BIN="$TMP/onsgmls"
fi

fail() { echo "cmscratch: FAIL — $1"; exit 1; }

# --- 1. both modes, byte for byte, over the model-heavy fixtures -----------
# Every corpus entry whose own DTD exercises content models: the two ambiguity
# fixtures (which report through the ambiguities vector compile() fills), the
# declared-content and element-structure ones, plus the repo's own big grammar.
CASES="synth-ambiguous-model synth-ambiguous-model-and synth-imply-declared-content
       synth-element-not-allowed synth-element-not-finished synth-entdata-content-model
       synth-decl-attlist-before-element synth-dup-element scaly expressions"

n=0
for c in $CASES; do
  d="tests/sgml/corpus/$c"
  [ -d "$d" ] || continue
  DOC=""; BASE="entry"; SP_ENV=""; EXTRA_ARGS=""; WORKDIR=""; RAST=0
  # shellcheck disable=SC1091
  . "$d/manifest"
  [ -n "$DOC" ] || continue
  case "$BASE" in repo) w="$ROOT" ;; *) w="$d" ;; esac
  [ -n "$WORKDIR" ] && case "$WORKDIR" in /*) w="$WORKDIR" ;; *) w="$d/$WORKDIR" ;; esac
  [ -d "$w" ] || continue

  ( cd "$w" && env $SP_ENV "$BIN" $EXTRA_ARGS "$DOC" ) > "$TMP/on.out" 2> "$TMP/on.err"; on_rc=$?
  ( cd "$w" && env $SP_ENV SP_CM_SCRATCH=0 "$BIN" $EXTRA_ARGS "$DOC" ) > "$TMP/off.out" 2> "$TMP/off.err"; off_rc=$?

  [ "$on_rc" = "$off_rc" ] || fail "$c: exit code $on_rc vs $off_rc"
  cmp -s "$TMP/on.out" "$TMP/off.out" || fail "$c: ESIS differs between modes"
  cmp -s "$TMP/on.err" "$TMP/off.err" || fail "$c: stderr differs between modes"
  n=$((n + 1))
done
[ "$n" -ge 8 ] || fail "only $n fixtures ran — the corpus moved, re-aim the list"

# --- 2. the counter, in both directions -----------------------------------
# The repo's own grammar (BASE=repo, so the workdir is the checkout root) is
# the biggest content-model population in the public tier.
CDIR="$ROOT"
CDOC="scaly.sgm"
stats_on=$( ( cd "$CDIR" && SP_CM_SCRATCH_STATS=1 "$BIN" -s "$CDOC" ) 2>&1 >/dev/null | grep '^cm-scratch:' )
stats_off=$( ( cd "$CDIR" && SP_CM_SCRATCH=0 SP_CM_SCRATCH_STATS=1 "$BIN" -s "$CDOC" ) 2>&1 >/dev/null | grep '^cm-scratch:' )

a_on=$(printf '%s' "$stats_on" | sed -n 's/.*arenas \([0-9]*\).*/\1/p')
h_on=$(printf '%s' "$stats_on" | sed -n 's/.*on host \([0-9]*\).*/\1/p')
a_off=$(printf '%s' "$stats_off" | sed -n 's/.*arenas \([0-9]*\).*/\1/p')
h_off=$(printf '%s' "$stats_off" | sed -n 's/.*on host \([0-9]*\).*/\1/p')

[ -n "$a_on" ] || fail "no counter line with the stats switch on"
[ "$a_on" -gt 0 ] || fail "default mode scratched nothing (arenas=$a_on) — the seam is off"
[ "$h_on" = 0 ] || fail "default mode compiled $h_on models on the host"
[ "$a_off" = 0 ] || fail "SP_CM_SCRATCH=0 still made $a_off arenas — the hatch is decoration"
[ "$h_off" -gt 0 ] || fail "SP_CM_SCRATCH=0 compiled nothing on the host"
[ "$a_on" = "$h_off" ] || fail "the two modes compiled different numbers of models ($a_on vs $h_off)"

# --- 3. the pages really came back ----------------------------------------
# A counter can be right while the release is a no-op, so the seam counts the
# scratch pages it hands to deallocate_exclusive_page. Every arena owns at
# least its own page, so pages >= arenas, and zero pages with a positive arena
# count is exactly the silent-no-op failure this leg exists for.
pg_on=$(printf '%s' "$stats_on" | sed -n 's/.*pages returned \([0-9]*\).*/\1/p')
pg_off=$(printf '%s' "$stats_off" | sed -n 's/.*pages returned \([0-9]*\).*/\1/p')
[ -n "$pg_on" ] || fail "the counter line has no page column"
[ "$pg_on" -ge "$a_on" ] || fail "only $pg_on pages returned for $a_on arenas — the release is a no-op"
[ "$pg_off" = 0 ] || fail "SP_CM_SCRATCH=0 returned $pg_off scratch pages"

# --- 4. and on a REAL DTD, the peak drops ---------------------------------
# The public tier's grammar is too small for the effect to clear page
# granularity (measured: identical to the byte on scaly.sgm), so this leg runs
# on the 198-KB DocBook DTD when it is available. ★It is reported either way —
# a skipped leg that prints nothing reads as a leg that passed.
DD="${DAZZLEDOC:-$HOME/repos/dazzledoc}"
peak_note="peak leg SKIPPED (no DAZZLEDOC; the public grammar is too small to show it)"
if [ -f "$DD/tiny.xml" ] && [ -f "$DD/docbook.dtd" ]; then
  peak() {
    /usr/bin/time -l "$@" >/dev/null 2>"$TMP/t" || :
    local b
    b=$(awk '/maximum resident set size/{print $1; f=1} END{if(!f) print ""}' "$TMP/t")
    if [ -z "$b" ]; then
      /usr/bin/time -v "$@" >/dev/null 2>"$TMP/t"
      b=$(awk -F': ' '/Maximum resident set size/{print $2*1024}' "$TMP/t")
    fi
    echo "${b:-0}"
  }
  p_on=$( cd "$DD" && peak env "$BIN" -s tiny.xml )
  p_off=$( cd "$DD" && peak env SP_CM_SCRATCH=0 "$BIN" -s tiny.xml )
  [ "$p_on" -gt 0 ] || fail "could not measure peak RSS"
  [ "$p_on" -lt "$p_off" ] || fail "scratch on is not smaller ($p_on vs $p_off bytes) on the DocBook DTD"
  peak_note="DocBook-DTD peak RSS -$(awk -v a="$p_on" -v b="$p_off" 'BEGIN{printf "%.1f", (b-a)*100/b}') %"
fi

echo "cmscratch: PASS ($n fixtures x 2 modes; $a_on models scratched, $pg_on pages returned, hatch disables; $peak_note)"
