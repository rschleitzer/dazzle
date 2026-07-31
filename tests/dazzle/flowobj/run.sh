#!/usr/bin/env bash
# tests/dazzle/flowobj/run.sh — the FLOW-OBJECT-CLASS suite: one fixture family
# per class bundle of COMPLETENESS.md gap (1), differentially against the
# reference C++ dazzle where it can run at all.
#
#   tests/dazzle/flowobj/run.sh [scalyc-binary]
#
# Home of the flow-object-class × backend fixtures. No corpus stylesheet
# touches these classes, so /usr/local/bin/dazzle is the only oracle — and for
# two of the cases it is no oracle at all (see below), where the golden is
# documented OUR behaviour with the reference line that explains why.
#
# ★Keep every .dsl in this directory PURE ASCII: a non-SGML character in a
# comment is a reference diagnostic ("non SGML character number 152") that this
# port does not raise, so a stray star turns the stderr golden into a
# divergence report about the fixture rather than about the feature.
#
# --- the inline/mark bundle: character, alignment-point, sideline, anchor,
#     glyph-annotation, emphasizing-mark ------------------------------------
#
# inline1 (-t fot): the positive matrix. Every one of `character`'s fifteen
# keyed characteristics, the three that print a WORD (an id-less glyph-id and
# a #f script render "false"; math-font-posture: #f is IN its allowed set), a
# characteristic-less `(make character)`, an inherited characteristic flushing
# through the ics buffer, both NIC-less classes and the lazy (non-constant)
# chain. ★It pins three reference quirks: `<character` ends with the RECORD END
# BEFORE the `/>`; `glyph-annotation`'s start tag is SELF-CLOSING and is then
# closed by `</glyph-annotation>`; and `anchor` — a CompoundFlowObj whose
# processInner never calls the base — accepts content and DISCARDS it, with no
# atomicContent diagnostic anywhere.
#
# inline2 (-2, -t fot): the diagnostic matrix — one conversion failure per
# characteristic (each leaves its field unspecified, so the dump stays silent),
# the unknown-keyword message per class, atomicContent for the two classes that
# really are atomic (character, alignment-point), and the one characteristic
# name that is no syntactic key: a `declare-char-characteristic+property` NIC,
# which CharacterFlowObj accepts and then DROPS without a word.
#
# inline3 (-t tex): the TeX backend's own rendering, and the only golden where
# the DERIVED characteristics are visible — setCharacterNIC dumps thirteen
# \def's under `valid`, in its own order, and without BreakAfterPriority (only
# the disabled #else branch of the reference has that one). ★`\def\Script`
# strips 29 bytes off the script's public identifier by pointer arithmetic.
#
# inline3b (-t tex): ★OUR behaviour. A character whose `script` property is #f
# makes that pointer arithmetic read from address 29: the reference binary
# SEGFAULTS (rc 139, EXC_BAD_ACCESS). This port renders an empty \Script, the
# same choice it already made for a #f public-id characteristic.
#
# inline4 (-t rtf) / inline4m (-t mif) / inline5 (-t sgml): the backends that
# override NOTHING of the family, so the plain FOTBuilder brackets decide. ★The base `character`
# EMITS THE CHARACTER AS TEXT before its atomic bracket, which is why an RTF
# stream carries "A" for a make whose every characteristic is invisible, and
# why the transform backend's whole output for this family is document text.
# inline5 stays inside the 8-bit range on purpose: above it the reference's
# output encoder falls back to numeric character references (the still-open
# OutputEncoder item of COMPLETENESS.md (5), unrelated to this family).
#
# emph1 (-t fot): ★OUR behaviour. `emphasizing-mark` cannot run in the
# reference binary at all — its copy constructor copies nic_ and forgets
# emphmark_ (style/EmphasizingMark.h:28), so every make of the class
# dereferences an indeterminate SosofoObj*; measured rc 138/139 on all six
# backends, with and without a mark:. The golden is the emission the
# reference's own SerialFOTBuilder/SgmlFOTBuilder code is written for.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "dazzle-flowobj: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

cp "$HERE"/*.sgml "$HERE"/*.dsl "$WORK/"

# a backend whose tree goes to the -o file (fot/tex/rtf/mif/html)
run_case() { # name backend [extra-flag] [stylesheet-base]
  local name="$1" backend="$2" flag="${3:-}" dsl="${4:-$1}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" $flag -t "$backend" -o "$name.out" -d "$dsl.dsl" fodoc.sgml \
      > "$name.stdout" 2> "$name.err" )
  compare "$name" "$name.out" "$?"
}

# the transform backend writes the instance to STDOUT
run_transform_case() { # name [extra-flag]
  local name="$1" flag="${2:-}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" $flag -t sgml -d "$name.dsl" fodoc.sgml \
      > "$name.out" 2> "$name.err" )
  compare "$name" "$name.out" "$?"
}

compare() { # name produced rc
  local name="$1" produced="$2" rc="$3"
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-flowobj: FAIL $name (rc=$rc)"; cat "$WORK/$name.err"; exit 1
  fi
  if ! diff -q "$HERE/$name.expected" "$WORK/$produced" > /dev/null; then
    echo "dazzle-flowobj: FAIL $name (output differs)"
    diff "$HERE/$name.expected" "$WORK/$produced" | head -14
    exit 1
  fi
  sed 's/^[^:]*:/PROG:/' "$WORK/$name.err" > "$WORK/$name.err.norm"
  if ! diff -q "$HERE/$name.experr" "$WORK/$name.err.norm" > /dev/null; then
    echo "dazzle-flowobj: FAIL $name (stderr differs)"
    diff "$HERE/$name.experr" "$WORK/$name.err.norm" | head -10
    exit 1
  fi
}

run_case inline1 fot
run_case inline2 fot -2
run_case inline3 tex
run_case inline3b tex
run_case inline4 rtf
# the same stylesheet on MIF, the third backend that overrides nothing of the
# family (the html backend was measured byte-identical too, but its only
# artefact for a scroll-less stylesheet is the .css file the html suite owns).
run_case inline4m mif "" inline4
run_transform_case inline5
run_case emph1 fot

echo "dazzle-flowobj: PASS"
