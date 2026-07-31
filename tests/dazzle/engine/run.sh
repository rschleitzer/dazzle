#!/usr/bin/env bash
# tests/dazzle/engine/run.sh — the ENGINE-SEMANTICS suite: the syntactic
# keyword table, the declaration forms, the pattern qualifiers and the query
# language, differentially against the reference C++ dazzle.
#
#   tests/dazzle/engine/run.sh [scalyc-binary]
#
# Home of the COMPLETENESS.md dimension-(5) fixtures. Every golden here is
# minted from /usr/local/bin/dazzle: these forms are reached by no corpus
# stylesheet, so the reference binary is the only oracle.
#
# ★These fixtures are MARKED SECTIONS (`<![CDATA[ … ]]>`) inside the .dsl,
# not SYSTEM .scm entities. A .scm read as an SGML entity cannot contain
# `<?` — that opens a processing instruction, and DSSSL names like `char<?`
# are perfectly ordinary. Same class as the `&name;` and `<angle bracket>`
# traps noted in tests/dazzle/prims/run.sh.
#
# key1 (without -2) + key2 (the SAME stylesheet with -2): the syntactic
# keyword table. ★`keys2[]` — `begin`, `set!`, `or-element` — is -2-ONLY:
# without the flag the first two are undefined variables and the third an
# unknown top level form. ★Under -2 every key whose name ends in `?` is ALSO
# bound without it, so `keep-with-previous:` is a valid make keyword there
# and an error without. ★`unknown top level form` fires both for a head with
# no key and for a key with no top-level meaning (`if`, `lambda`); exactly
# three keys are skipped in silence — declare-reference-value-type,
# define-page-model, define-column-set-model — and those were not even
# installed as keys before. The golden also pins the reference's RECOVERY
# suppression: after the first unknown form the following ones report
# nothing.

# pat1..pat4 (patdoc.sgml): the PATTERN QUALIFIERS — Style/Pattern.cxx plus
# the keyword half of Interpreter::convertToPattern, which is dsssl2-ONLY.
# pat2 (-2) is the positive matrix: the ancestor chain, the three repeat
# metacharacters, the #t wildcard element, the attribute qualifiers with
# their -2-only #t/#f values, id:/class: against declare-id-attribute /
# declare-class-attribute, the four position: and two only: qualifiers,
# children:, and the vacuous priority:/importance:. pat1 is the same feature
# WITHOUT -2, where every keyword qualifier is `cannot occur in a pattern`
# and the two declarations are unknown top level forms. pat3 walks every
# convertToPattern diagnostic, one malformed pattern per rule. pat4 is
# SPECIFICITY: which of several matching rules wins, and the ambiguity
# diagnostic — ★whose LOCATION is the element's start tag, the one grove
# node location this port needs (the reference's LocNode). ★pat4's two tied
# rules print the same text on purpose: the reference sorts with qsort,
# so which member of an equal-specificity run fires is not a contract.

# prop1 (propdoc.sgml): CHARACTER PROPERTIES — the thirteen built-in
# properties of installCharProperties, the declare-char-property /
# add-char-properties declarations and the char-property primitive. ★It pins
# the three-step fallback (the character's own value, then the CALLER's
# optional default, then the declared one), that a declared default must be a
# CONSTANT (even `(+ 1 2)` is rejected — the reference asks for
# constantValue() after optimizing, and a call never folds), the duplicate
# declaration with its AUXILIARY "first definition was here" line, and the
# built-in tables themselves including `script`, whose value is the ISO
# public identifier plus the script name. ★math-class is the one built-in
# whose default is neither a boolean nor a number but the SYMBOL `ordinary`;
# the three the reference creates EMPTY (glyph-id, both drop-*-line-break?)
# answer #f. The diagnostics point at the VALUE EXPRESSION, not the form.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "dazzle-engine: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

cp "$HERE"/*.sgml "$HERE"/*.dsl "$WORK/"

run_case() { # name document expected_err [extra-flag]
  local name="$1" doc="$2" experr="$3" flag="${4:-}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" $flag -t sgml -d "$name.dsl" "$doc" > "$name.out" 2> "$name.err" )
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-engine: FAIL $name (rc=$rc)"; cat "$WORK/$name.err"; exit 1
  fi
  if ! diff -q "$HERE/$name.expected" "$WORK/$name.out" > /dev/null; then
    echo "dazzle-engine: FAIL $name (output differs)"
    diff "$HERE/$name.expected" "$WORK/$name.out" | head -14
    exit 1
  fi
  sed 's/^[^:]*:/PROG:/' "$WORK/$name.err" > "$WORK/$name.err.norm"
  if ! diff -q "$HERE/$experr" "$WORK/$name.err.norm" > /dev/null; then
    echo "dazzle-engine: FAIL $name (stderr differs)"
    diff "$HERE/$experr" "$WORK/$name.err.norm" | head -10
    exit 1
  fi
}

run_case key1 keydoc.sgml key1.experr
run_case key2 keydoc.sgml key2.experr -2
run_case prop1 propdoc.sgml prop1.experr
run_case pat1 patdoc.sgml pat1.experr
run_case pat2 patdoc.sgml pat2.experr -2
run_case pat3 patdoc.sgml pat3.experr -2
run_case pat4 patdoc.sgml pat4.experr -2

echo "dazzle-engine: PASS"
