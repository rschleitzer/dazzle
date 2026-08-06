#!/usr/bin/env bash
# tests/dazzle/prims/run.sh — the PRIMITIVE suite: the DSSSL built-in
# procedures of style/primitive.h, differentially against the reference C++
# dazzle.
#
#   tests/dazzle/prims/run.sh [scalyc-binary]
#
# Home of the COMPLETENESS.md work-package-7 fixtures (primitive completeness).
# Every golden here is minted from /usr/local/bin/dazzle: these primitives are
# reached by no corpus document, so the reference binary is the only oracle.
#
# num1 (doc.sgml): the NUMERIC / TRANSCENDENTAL family — min, max, floor,
# ceiling, truncate, round, sqrt, exact?, inexact?, exp, log, sin, cos, tan,
# asin, acos, atan (both arities), expt, exact->inexact, inexact->exact — as
# VALUES, with the result's exactness printed alongside it. It pins the two
# exactness rules that carry the family: an exact integer passes through the
# rounding primitives UNCHANGED, and a double argument to min/max converts the
# accumulator even when it LOSES (at dimension 0). ★It also pins two shapes
# that look like slips and are not: `(sqrt 2)` answers a dimension-0
# QuantityObj, which prints "1.41421pt0", and `(expt 2 -1)` answers the exact
# integer 0, because both arguments were exact so the reference casts 0.5 to a
# long.
# num2 (doc2.sgml): the DIAGNOSTICS and the dimension rules, one probe per
# element because an error result unwinds its whole construction rule. It pins
# which primitives gate on quantityValue (notAQuantity) and which on realValue
# (notANumber) for the same bad argument, that a LENGTH fails the realValue
# gate so floor/atan/expt reject it, the outOfRange domains, and
# incompatibleDimensions across min/max/atan2. ★Two probes return a VALUE
# after reporting: inexact->exact of a non-integral real reports
# noExactRepresentation and still yields its argument (the C++ case label has
# no break), and of a non-integral LENGTH reports nothing at all, because a
# length is a longQuantity and takes the silent fall-through arm.
# list1 (doc4.sgml): the remaining primitives that need no -2 — assoc (which
# compares with ELObj::equal, so an equal STRING key hits), map-constructor
# (a ZERO-argument procedure per node, sosofos appended — its arity gate is
# the mirror image of node-list-map's), quantity? and quantity->number. ★It
# pins the split that runs through this whole package: `quantity?` is the
# quantityValue gate and `number?` the realValue one, so a LENGTH is a
# quantity and NOT a number, and quantity->number scales a dimensioned value
# into metres per dimension and turns it inexact.
# gate1 (doc5.sgml) + dsssl2 (doc5.sgml, WITH -2): the -2 GATE. The eleven
# PRIMITIVE2 entries plus call-with-current-continuation and the
# string->quantity alias are undefined variables without the flag and
# procedures with it. The same golden also pins the SEVEN names this port
# used to define that primitive.h has no entry for at all (assq, memq,
# char->integer, integer->char, vector-length, process-node, call/cc) —
# undefined in both modes.
# vec1 (doc6.sgml, WITH -2): the -2-only primitives at work, including the
# newly ported vector-fill! and quantity->string (which prints the lengths
# number->string refuses).
# ent1 (entdoc.sgml, a copy of the grove suite's decls.sgml): the ENTITY and
# NOTATION lookups — entity-text, entity-type, entity-attribute-string,
# entity-name-normalize and the three notation-*-id, over the four that were
# already ported, across one entity of EVERY declared type and three notation
# shapes. ★It found two lookup bugs that also affected the four older
# primitives: these names resolve through the sgml-document `entities` named
# node list, which carries the DEFAULTED-ENTITY FALLBACK (so a PARAMETER
# entity is findable), and through the `notations` list, which FOLDS the
# queried name with the general substitution table (so a lowercase notation
# name finds its upper-cased declaration). The golden also pins that these
# primitives cannot distinguish "no such entity" from "no such property" —
# every failed link collapses to the same #f — with entity-name-normalize the
# lone exception, which always answers a string.
# num4 (numdoc.sgml): the NUMBERING family — ancestor-child-number,
# hierarchical-number, element-number-list, first-child-gi and
# node-list-no-order, over three chapters whose middle one has two sections,
# so a probe paragraph has a real (chapter, section, paragraph) coordinate.
# ★element-number-list reads OUTERMOST-first and each level is reset by the
# level BEFORE it — (2 1 2), not the other way round. ★ancestor-child-number
# starts at the PARENT, so a node is never its own ancestor. ★When
# hierarchical-number runs out of ancestors, every remaining GI scores 0
# rather than the call failing. The fixture also pins general-name-normalize,
# whose fold three other primitives turned out to be missing:
# element-with-id, process-element-with-id and the GI matching here all
# resolve a lowercase name against upper-cased element storage.
# num5 (numdoc.sgml): the NUMBERING CACHE's state machine (NumberCache.cxx).
# num4 pins what the numbering primitives ANSWER; num5 pins that they answer
# the SAME when the cache carries state from an earlier query — the same node
# twice, a node BEFORE the cached position (the walk has to restart at the
# document element rather than run off the end), two GIs interleaved, and
# element-number-list mixed in, which keys its entry by the RESET gi and
# stores a sub-position the plain form clears. ★Every value here is
# order-independent by construction, so a cache that answers from a stale
# position shows up as a wrong NUMBER, not as a crash.
# num7 (numdoc.sgml): the same treatment for the SECOND cache — child-number's
# per-LEVEL, per-GI entry (NumberCache::childNumber) and the grove's one-entry
# sibling hint (GroveNode.group_index), which last-sibling? and
# absolute-last-sibling? start their forward walk from. ★The level dimension
# is the one num5 has no counterpart for: `p` appears both as a chapter child
# and as a section child, so a single shared entry would resume the count in
# the wrong group, and the fixture asks the two levels alternately. The
# sibling half asks across groups and backwards for the same reason.
# proc1 (procdoc.sgml) + proc2 (procdoc.sgml, `-t fot`): the PROCESS /
# SOSOFO / STYLE cluster — process-first-descendant, process-matching-
# children, sosofo-label, sosofo-discard-labeled, merge-style, style?,
# match-element? and inherited-element-attribute-string. ★merge-style really
# applies and its FIRST part wins a conflict; process-first-descendant
# excludes the node itself (DescendantsNodeListObj advances in its own
# constructor) and stops at the first hit, while process-matching-children
# takes all of them and is the empty sosofo when given no pattern at all;
# inherited-element-attribute-string keeps CLIMBING when the GI matches but
# the attribute is absent. ★proc2 is separate because the discard needs a
# backend with a CAPTURE SEAM: the `-t sgml` transform builder has none in
# this port, so connected content leaks there — a pre-existing gap of the
# connection machinery (label: and content-map: share it), named in
# COMPLETENESS.md.
# lang1 + lang2 (langdoc.sgml): the LANGUAGE / COLLATION cluster, with and
# without a declared default language. Both are MARKED SECTIONS inside the
# .dsl rather than a SYSTEM .scm entity, because `char<?` cannot survive SGML
# parsing — `<?` opens a processing instruction.
# ★lang1 pins the measured heart of the cluster: a define-language with no
# `collate` clause has ZERO collating levels, so LangObj::compare is 0 for
# EVERY pair — `char<?` is always #f, `char<=?` always #t, string-equiv?
# always #t, whatever the code points say. char=? and string=? stay
# code-point tests. It also pins with-language rebinding and restoring, and
# that an unmapped character folds to ITSELF (there is no ASCII fallback
# behind a language).
# ★lang2 pins the deviation this package CLOSED: without a language every
# collating primitive reports `no current language` and yields the error
# object. This port used to answer anyway, comparing code points and folding
# ASCII. The diagnostic has no file/line because the reference's GETCURLANG
# macro calls message() without setNextLocation.
# ★ONE DOCUMENTED DIVERGENCE, pinned with OUR value in lang1.expected:
# `(language "en" "US")` under the OpenJade public id. The reference binary
# is built with SP_HAVE_LOCALE + SP_HAVE_WCHAR and returns a RefLangObj — a
# live C locale calling setlocale + wcscoll + towupper around every
# comparison; we return #f, which is what the reference returns without those
# macros. See COMPLETENESS.md.
# time1 + time2 (langdoc.sgml): the TIME family — time, time->string and the
# four comparisons over timeConv, the last primitives of primitive.h that
# needed a C shim (packages/scaly/0.1.0/scaly/time/ctime.c: struct tm plus
# variadic sscanf/sprintf, containment rule (a)+(b)). Both run under a FIXED
# TZ so localtime is deterministic without tzdata, and both are MARKED
# SECTIONS rather than SYSTEM .scm entities for lang1's reason — `time<?`
# cannot survive SGML parsing, `<?` opens a processing instruction.
# ★time1 pins timeConv's four measured quirks as contract: a bare year is
# December FIRST OF THE YEAR BEFORE (the switch falls through case 1 and case
# 2 into the month decrement, so the "January First" comment above it is
# wrong); an unparsable string errors but an EMPTY one does NOT (sscanf
# answers 0 for the first and EOF for the second, and EOF lands in the
# `default` arm); a 4-digit year below 1900 is left alone, so "1000-01-01" is
# the year 2900; and the Y2K window turns "37" into 2037 but leaves "38" at
# 1938. ★time2 pins the two argument gates and, with them, the installed
# signatures: an over-long call reports `too many arguments for function` and
# the primitive still runs and yields its value.
# num3 (doc3.sgml): the XXPRIMITIVE `expt` under the OpenJade public id, which
# external-procedure reaches and the identifier does not. ★Its golden records
# a MEASURED reference defect as contract: primitive.cxx:5042 reads the second
# quantity from argv[0], so `(xexpt 2.0 3.0)` is 4 and `(xexpt 2.0 "x")` is 4
# with no diagnostic at all. See COMPLETENESS.md for the half that is NOT
# reproduced (an exact-integer base, where the reference powers uninitialized
# stack).

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "dazzle-prims: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

# inputs are COPIED into a scratch workdir (outputs must never land next to the
# repo fixtures).
cp "$HERE"/*.sgml "$HERE"/*.dsl "$HERE"/*.scm "$WORK/"

run_case() { # name document [expected_err] [extra-flag]
  local name="$1" doc="$2" experr="${3:-}" flag="${4:-}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" $flag -t sgml -d "$name.dsl" "$doc" > "$name.out" 2> "$name.err" )
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-prims: FAIL $name (rc=$rc)"; cat "$WORK/$name.err"; exit 1
  fi
  if ! diff -q "$HERE/$name.expected" "$WORK/$name.out" > /dev/null; then
    echo "dazzle-prims: FAIL $name (output differs)"
    diff "$HERE/$name.expected" "$WORK/$name.out" | head -14
    exit 1
  fi
  if [ -n "$experr" ]; then
    sed 's/^[^:]*:/PROG:/' "$WORK/$name.err" > "$WORK/$name.err.norm"
    if ! diff -q "$HERE/$experr" "$WORK/$name.err.norm" > /dev/null; then
      echo "dazzle-prims: FAIL $name (stderr differs)"
      diff "$HERE/$experr" "$WORK/$name.err.norm" | head -10
      exit 1
    fi
  elif [ -s "$WORK/$name.err" ]; then
    echo "dazzle-prims: FAIL $name (unexpected stderr)"; cat "$WORK/$name.err"; exit 1
  fi
}

run_case num1 doc.sgml
run_case num2 doc2.sgml num2.experr
run_case num3 doc3.sgml num3.experr
run_case list1 doc4.sgml list1.experr
run_case gate1 doc5.sgml gate1.experr
run_case dsssl2 doc5.sgml dsssl2.experr -2
run_case vec1 doc6.sgml vec1.experr -2
run_case ent1 entdoc.sgml
run_case num4 numdoc.sgml
run_case num5 numdoc.sgml
run_case num7 numdoc.sgml
run_case num6 doc.sgml
run_case proc1 procdoc.sgml proc1.experr

# proc2 runs on `-t fot`, which needs -o and has the capture seam the
# transform builder lacks.
run_fot_case() { # name document expected_err
  local name="$1" doc="$2" experr="$3"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" -t fot -o "$name.out" -d "$name.dsl" "$doc" 2> "$name.err" )
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-prims: FAIL $name (rc=$rc)"; cat "$WORK/$name.err"; exit 1
  fi
  sed 's/^[^:]*:/PROG:/' "$WORK/$name.err" > "$WORK/$name.err.norm"
  if ! diff -q "$HERE/$experr" "$WORK/$name.err.norm" > /dev/null; then
    echo "dazzle-prims: FAIL $name (stderr differs)"
    diff "$HERE/$experr" "$WORK/$name.err.norm" | head -10
    exit 1
  fi
  if ! diff -q "$HERE/$name.expected" "$WORK/$name.out" > /dev/null; then
    echo "dazzle-prims: FAIL $name (output differs)"
    diff "$HERE/$name.expected" "$WORK/$name.out" | head -14
    exit 1
  fi
}
run_fot_case proc2 procdoc.sgml proc2.experr
run_case lang1 langdoc.sgml lang1.experr
run_case lang2 langdoc.sgml lang2.experr

# time1/time2 need a FIXED local zone: `time->string` without a gmt argument
# and timeConv's mktime both read it. EST5 is a POSIX TZ string — a plain
# offset with no DST rule — so it resolves without a tzdata database (a bare
# CI container has none) and still differs from UTC, which is what makes the
# local/gmt split observable.
run_tz_case() { # name document [expected_err]
  ( export TZ=EST5; run_case "$@" ) || exit 1
}
run_tz_case time1 langdoc.sgml
run_tz_case time2 langdoc.sgml time2.experr

echo "dazzle-prims: PASS"
