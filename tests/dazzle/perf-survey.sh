#!/usr/bin/env bash
# tests/dazzle/perf-survey.sh — wall / CPU / peak-RSS survey of the Scaly
# opensp+dazzle port against the C++ reference (OpenSP onsgmls, openjade).
#
#   tests/dazzle/perf-survey.sh [runs]        # default 7 runs, median reported
#
# Environment:
#   ONSGMLS_BIN  port event dumper   (default: build it into a temp dir)
#   DAZZLE_BIN   port DSSSL CLI      (default: build it into a temp dir)
#   REF_ONSGMLS  reference parser    (default: /usr/local/bin/onsgmls, else PATH)
#   REF_JADE     reference engine    (default: dazzle, else openjade)
#   DAZZLEDOC    DocBook workload    (default: $HOME/repos/dazzledoc)
#   CLAML        ClaML workload      (no default — the corpus lives in a
#                                     local-only repo, see the note below)
#
# Paths of your own machine do not belong in this file. Put them in the
# gitignored `tests/dazzle/perf-survey.local` instead, which is sourced when
# CLAML is not already in the environment:
#
#   CLAML=$HOME/repos/<repo>/<path-to-claml-corpus>
#
# The two external corpora are optional; missing ones are skipped with a note.
# Each row first runs both sides ONCE and diffs the output — a row whose output
# differs is reported as MISMATCH and its timings are meaningless. The codegen
# row writes its generated files into a scratch directory, never the tree.
#
# Numbers are medians over `runs` runs. `cpu` is user+sys; on this engine it
# tracks wall almost exactly (single-threaded, no `for` self-scaling fires).

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RUNS="${1:-7}"
REF_ONSGMLS="${REF_ONSGMLS:-}"
if [ -z "$REF_ONSGMLS" ]; then
  # ★The same doctrine as REF_JADE below, and it took until 2026-08-08 to apply
  # it here: the right reference is the OpenSP built from the PORTING SOURCE
  # (~/repos/dazzle/opensp -> /usr/local/bin), not whatever `onsgmls` is on
  # PATH.  A distribution build (MacPorts, Homebrew) of the same 1.5.2 carries
  # a CONSTANT ~4 MB more RSS on every workload — it links libintl, which the
  # porting build does not — and that offset silently flattered every parse row
  # of this survey: measured the same day, ClaML's RSS factor is 3.48x against
  # the MacPorts binary and 6.57x against this one, and the "our process socket
  # is SMALLER than the reference's" row (0.57x) is really 1.14x.  ESIS output
  # and multi-byte handling are identical between the two builds.
  if [ -x /usr/local/bin/onsgmls ]; then REF_ONSGMLS=/usr/local/bin/onsgmls
  else REF_ONSGMLS=onsgmls; fi
fi
REF_JADE="${REF_JADE:-}"
if [ -z "$REF_JADE" ]; then
  # dazzle (openjade 1.3.3-pre1) is the porting source and the right baseline:
  # openjade 1.3.2 predates e.g. the RTF stylesheet's "{\\s0 Normal;}" entry, so
  # it reports a 13-byte "mismatch" that is a reference-version difference, not
  # a port defect (measured 2026-08-01; the port matches dazzle byte for byte).
  if command -v dazzle >/dev/null 2>&1; then REF_JADE=dazzle; else REF_JADE=openjade; fi
fi
DAZZLEDOC="${DAZZLEDOC:-$HOME/repos/dazzledoc}"
if [ -z "${CLAML:-}" ] && [ -f "$HERE/perf-survey.local" ]; then
  . "$HERE/perf-survey.local"
fi
CLAML="${CLAML:-}"
cd "$ROOT"
set -u

# The codegen row's style sheet writes files relative to the WORKING
# DIRECTORY: it runs in $GEN, a scratch directory with the output tree's shape
# (the frozen fixture of tests/dazzle/framemark, whose run.sh has the account).
# Each run overwrites the last one's files, so there is nothing to restore —
# restore_generated stays as the hook a row's `restore` argument calls.
restore_generated() { :; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
GEN="$TMP/gen"
mkdir -p "$GEN/packages/scalyc/0.1.0/scalyc/compiler" "$GEN/packages/scalyls/0.1.0/scalyls" \
  "$GEN/editors/vscode/syntaxes"

# --- binaries -------------------------------------------------------------
ONS="${ONSGMLS_BIN:-}"
DZ="${DAZZLE_BIN:-}"
if [ -z "$ONS" ]; then
  ONS="$TMP/onsgmls"
  tests/sgml/build-onsgmls.sh "$ONS" > "$TMP/b1.log" 2>&1 || { echo "perf-survey: FAIL (build onsgmls)"; tail -8 "$TMP/b1.log"; exit 1; }
fi
if [ -z "$DZ" ]; then
  DZ="$TMP/dazzle"
  tests/dazzle/build-cli.sh "$DZ" > "$TMP/b2.log" 2>&1 || { echo "perf-survey: FAIL (build dazzle)"; tail -8 "$TMP/b2.log"; exit 1; }
fi

XMLENV="SP_CHARSET_FIXED=YES SP_ENCODING=XML"

# --- measurement ----------------------------------------------------------
# one <cwd> <env-prefix> <cmd> <stdout-file> -> "wall user sys rssbytes"
one() {
  local cwd="$1" envp="$2" cmd="$3" out="$4"
  local t="$TMP/time"
  # The env prefix goes through `export`, not a command prefix: with REPEAT the
  # command is a `for` loop, and `VAR=x for ...` is a syntax error. Guard the
  # empty case — bare `export` dumps the whole environment to stdout.
  local pre=""
  [ -n "$envp" ] && pre="export $envp;"
  if /usr/bin/time -l bash -c "cd '$cwd'; $pre $cmd" > "$out" 2> "$t"; then :; else
    echo "perf-survey: command failed: $envp $cmd" >&2
    grep -v -e 'maximum resident' -e ' real ' -e 'page reclaims' -e 'context switches' \
         -e 'instructions retired' -e 'cycles elapsed' -e 'memory footprint' -e 'faults' \
         -e 'messages ' -e 'signals received' -e 'swaps' -e 'block ' -e 'shared memory' \
         -e 'unshared' -e 'integral' -e 'peak memory' "$t" | tail -5 >&2
    echo "0 0 0 0"; return
  fi
  awk '/ real +.* user +.* sys/{w=$1;u=$3;s=$5}
       /maximum resident set size/{r=$1}
       /Maximum resident set size/{split($0,a,": ");r=a[2]*1024}
       /Elapsed \(wall clock\)/{split($0,a,": ");split(a[2],b,":");w=(length(b)==3)?b[1]*3600+b[2]*60+b[3]:b[1]*60+b[2]}
       /User time \(seconds\)/{split($0,a,": ");u=a[2]}
       /System time \(seconds\)/{split($0,a,": ");s=a[2]}
       END{printf "%s %s %s %s\n", w+0, u+0, s+0, r+0}' "$t"
}

# median of stdin numbers
median() { sort -g | awk '{v[NR]=$1} END{if(NR==0){print 0}else{print v[int((NR+1)/2)]}}'; }

# series <cwd> <envp> <cmd> -> "wall cpu rss" medians
#
# A run under 100 ms is below the resolution of `/usr/bin/time` (10 ms ticks),
# so short workloads set REPEAT=N: the command runs N times inside one timed
# shell and wall/cpu are divided by N. Peak RSS is unaffected — rusage reports
# the maximum over all children, and the children are identical.
series() {
  local cwd="$1" envp="$2" cmd="$3" i body
  body="$cmd"
  [ "$REPEAT" -gt 1 ] && body="for _i in \$(seq $REPEAT); do $cmd || exit 1; done"
  : > "$TMP/w"; : > "$TMP/c"; : > "$TMP/r"
  for ((i=0;i<RUNS;i++)); do
    read -r w u s r <<< "$(one "$cwd" "$envp" "$body" "$TMP/discard")"
    awk -v v="$w" -v n="$REPEAT" 'BEGIN{print v/n}' >> "$TMP/w"
    awk -v u="$u" -v s="$s" -v n="$REPEAT" 'BEGIN{print (u+s)/n}' >> "$TMP/c"
    echo "$r" >> "$TMP/r"
    [ "$RESTORE" = 1 ] && restore_generated
  done
  echo "$(median < "$TMP/w") $(median < "$TMP/c") $(median < "$TMP/r")"
}

hdr() {
  printf "\n%-26s %8s %8s %10s   %8s %8s %10s   %6s %6s %6s\n" \
    "workload" "wall" "cpu" "peak RSS" "wall" "cpu" "peak RSS" "wall" "cpu" "RSS"
  printf "%-26s %8s %8s %10s   %8s %8s %10s   %6s %6s %6s\n" \
    "" "(port)" "(port)" "(port)" "(ref)" "(ref)" "(ref)" "x" "x" "x"
  printf -- "%s\n" "----------------------------------------------------------------------------------------------------"
}

fotnorm() { python3 -c "
import re,sys
d=open(sys.argv[1],encoding='utf-8',errors='surrogateescape').read()
sys.stdout.write(re.sub(r'</text>\n?<text>','',d))
" "$1"; }

mb() { awk -v b="$1" 'BEGIN{printf "%.1f MB", b/1048576}'; }
ratio() { awk -v a="$1" -v b="$2" 'BEGIN{if(b==0){print "n/a"}else{printf "%.2f", a/b}}'; }

# row <label> <cwd> <envp> <port-cmd> <ref-cmd> [verify:0|1] [restore:0|1]
#
# Set REPEAT before the call for sub-100 ms workloads. Set PART/RART to the
# artifact files a row writes with -o; unset, the diff compares stdout.
row() {
  local label="$1" cwd="$2" envp="$3" pcmd="$4" rcmd="$5" verify="${6:-1}" rest="${7:-0}"
  RESTORE="$rest"
  local note=""
  if [ "$verify" = 1 ] && [ -n "$rcmd" ]; then
    one "$cwd" "$envp SCALY_HOME=$ROOT" "$pcmd" "$TMP/po" >/dev/null
    [ "$rest" = 1 ] && restore_generated
    one "$cwd" "$envp" "$rcmd" "$TMP/ro" >/dev/null
    [ "$rest" = 1 ] && restore_generated
    if [ -n "$PART" ]; then
      # `-t fot` carries ONE deliberate deviation: where a run of adjacent
      # <text> elements is broken (the reference's break points are an artifact
      # of its 8192-byte read blocks — see tests/dazzle/fot/textrun-deviation.sh,
      # which pins it and proves the content identical). Join adjacent runs on
      # both sides before comparing; NOTHING else is normalised, so any real
      # difference still shows up here.
      if [ "${PART##*.}" = fot ]; then
        fotnorm "$PART" > "$TMP/pn" && fotnorm "$RART" > "$TMP/rn" \
          && cmp -s "$TMP/pn" "$TMP/rn" || note="  ** OUTPUT MISMATCH **"
      else
        cmp -s "$PART" "$RART" || note="  ** OUTPUT MISMATCH **"
      fi
    else
      cmp -s "$TMP/po" "$TMP/ro" || note="  ** OUTPUT MISMATCH **"
    fi
  fi
  read -r pw pc pr <<< "$(series "$cwd" "$envp SCALY_HOME=$ROOT" "$pcmd")"
  if [ -z "$rcmd" ]; then
    printf "%-26s %7.3fs %7.3fs %10s   %8s %8s %10s   %6s %6s %6s%s\n" \
      "$label" "$pw" "$pc" "$(mb "$pr")" "-" "-" "-" "-" "-" "-" "  (port only)"
    REPEAT=1; PART=""; RART=""
    return
  fi
  read -r rw rc rr <<< "$(series "$cwd" "$envp" "$rcmd")"
  printf "%-26s %7.3fs %7.3fs %10s   %7.3fs %7.3fs %10s   %6s %6s %6s%s\n" \
    "$label" "$pw" "$pc" "$(mb "$pr")" "$rw" "$rc" "$(mb "$rr")" \
    "$(ratio "$pw" "$rw")" "$(ratio "$pc" "$rc")" "$(ratio "$pr" "$rr")" "$note"
  REPEAT=1; PART=""; RART=""
}
REPEAT=1; PART=""; RART=""

echo "perf-survey: $RUNS runs per cell, median reported"
echo "  port parser : $ONS"
echo "  port engine : $DZ"
echo "  reference   : $($REF_ONSGMLS -v </dev/null 2>&1 | head -1), $($REF_JADE -v </dev/null 2>&1 | head -1)"
echo "  host        : $(uname -sm), $(sysctl -n hw.ncpu 2>/dev/null || nproc) cores"

hdr

# ---- 1. parsing (event dump) --------------------------------------------
REPEAT=20
row "parse scaly.sgm 25K" "$ROOT/tests/sgml/corpus/scaly" "" \
  "$ONS scaly.sgm" "$REF_ONSGMLS scaly.sgm"

if [ -f "$DAZZLEDOC/dsssl.xml" ]; then
  REPEAT=5
  row "parse dsssl.xml 977K" "$DAZZLEDOC" "$XMLENV" \
    "$ONS dsssl.xml" "$REF_ONSGMLS dsssl.xml"
else
  echo "  (dazzledoc corpus missing at $DAZZLEDOC — parse/style rows skipped)"
fi

CLAMLDOC=""
[ -n "$CLAML" ] && CLAMLDOC="$CLAML/icd10gm2022syst_claml_20210917.xml"
if [ -n "$CLAMLDOC" ] && [ -f "$CLAMLDOC" ]; then
  row "parse ClaML 13.7M" "$CLAML" "$XMLENV" \
    "$ONS $(basename "$CLAMLDOC")" "$REF_ONSGMLS $(basename "$CLAMLDOC")"
elif [ -n "$CLAML" ]; then
  echo "  (ClaML corpus missing at $CLAML — large rows skipped)"
else
  echo "  (CLAML unset — large rows skipped; see the header note)"
fi

# ---- 2. DSSSL codegen (the Scaly grammar's code generator, frozen) -------
# Output goes into $GEN, not to stdout; tests/dazzle/framemark/run.sh is the
# byte-identity proof, so this row measures only.
REPEAT=10
CG_SPEC="$ROOT/tests/dazzle/framemark/spec/scaly.dsl"
CG_DOC="$ROOT/tests/sgml/corpus/scaly/scaly.sgm"
row "codegen scaly.dsl -t sgml" "$GEN" "" \
  "$DZ -t sgml -d $CG_SPEC $CG_DOC" \
  "$REF_JADE -G -t sgml -d $CG_SPEC $CG_DOC" 0 1

# ---- 3. DSSSL styling (DocBook print stylesheets over dsssl.xml) ---------
if [ -f "$DAZZLEDOC/dsssl.xml" ]; then
  for BE in fot rtf tex; do
    PART="$TMP/p.$BE"; RART="$TMP/r.$BE"
    row "dazzledoc -t $BE" "$DAZZLEDOC" "$XMLENV" \
      "$DZ -t $BE -d dsssl-stylesheets/print/docbook.dsl -o $TMP/p.$BE dsssl.xml" \
      "$REF_JADE -t $BE -d dsssl-stylesheets/print/docbook.dsl -o $TMP/r.$BE dsssl.xml"
  done
fi

# ---- 4. DSSSL transform (ClaML -> JSON) ----------------------------------
# Reference-only defect: openjade/dazzle write a nondeterministic 20-40 KB
# fragment of the 1 272 557-byte result here (measured 2026-08-01), so this row
# is port-only. Correctness is pinned against the checked-in icd10.json.
if [ -f "$CLAMLDOC" ]; then
  row "transform ClaML -t sgml" "$CLAML" "$XMLENV" \
    "$DZ -t sgml -d transform/icd10.dsl $(basename "$CLAMLDOC")" "" 0
  # -t sgml writes the result entity into the corpus directory (icd10.json),
  # not to stdout — save the checked-in golden, run, compare, restore.
  cp "$CLAML/icd10.json" "$TMP/icd10.golden"
  one "$CLAML" "$XMLENV SCALY_HOME=$ROOT" \
    "$DZ -t sgml -d transform/icd10.dsl $(basename "$CLAMLDOC")" "$TMP/icd" >/dev/null
  if cmp -s "$CLAML/icd10.json" "$TMP/icd10.golden"; then
    echo "  (transform output byte-identical to the checked-in icd10.json)"
  else
    echo "  ** transform output DIFFERS from icd10.json **"
  fi
  cp "$TMP/icd10.golden" "$CLAML/icd10.json"
fi

echo
