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

# query1..query5 (patdoc.sgml): the DSSSL QUERY LANGUAGE and, next door, the
# two parse shapes it leans on. query1 (no -2) is the semantic matrix of the
# four forms - they are keys[] entries, so they need no flag; query2 (-2)
# adds only the `?`-less ALIAS, which makes `there-exists` and `for-all` the
# same keys. ★The operator of a query form is resolved at PARSE time through
# Identifier::computeBuiltinValue, so a stylesheet that redefines
# node-list-filter changes its own calls and never `select-each` - the only
# reason Identifier carries a builtin shadow. query3 walks every malformed
# query form. ★query4/query4b pin parseBegin: an EMPTY body is `unexpected
# token ")"` in both modes, but the SEQUENCE body is -2-only and a second
# expression without the flag is `missing closing parenthesis` reported
# TWICE (tokenRecover ungets and answers SUCCESS). ★query5 pins that the
# top-level loop NEVER skips a failed form - it reads on token by token, so
# a construction rule buried inside `(bogus ...)` is really installed.

# macro1..macro4 (patdoc.sgml): declare-flow-object-macro and the
# MacroFlowObj it binds. macro1 (-2) is the positive matrix: characteristics
# given / defaulted / #f, a default reading the characteristic declared before
# it, #!contents used twice and not at all, the process-children default
# content, a non-constant characteristic through the lazy chain, nesting, a
# characteristic shadowing `font-size` and `label`, and the fact that a second
# declaration of the same macro name simply wins. macro1b is the SAME file
# without -2, where the form is `unknown top level form` (it is a keys2[]
# entry) and every make an unknown class - which reports NO invalid keyword,
# because unknownStyleKeyword bails out on a null flowObj. macro2 walks the
# declaration and make diagnostics, including the body/content
# CheckSosofoInsn. macro3 has the duplicate gate - which reads the
# CHARACTERISTIC definition record, so declare-characteristic refuses a later
# macro AND a later flow object class of that name while a built-in
# characteristic name (part -1) does not - plus, LAST, the one malformed form
# whose recovery swallows the rest of the entity. macro4 is `-t fot`, the only
# place where the startSequence/endSequence bracket and the style of a macro
# make are visible.

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

# ccp1 / ccp1b (propdoc.sgml): declare-char-characteristic+property — the one
# declaration that installs BOTH a char NIC (a non-inherited characteristic of
# the `character` flow object, a flag on the Identifier) and a char property
# of that name. ★Its duplicate gate is the MIRROR IMAGE of
# declare-characteristic's: a name carrying a characteristic is refused with
# NO part comparison — a BUILT-IN one too, and that one prints no auxiliary
# line because a built-in's location is empty — while a name already
# registered as a char NIC is refused only within the same part. ★The reverse
# gate is new here too: a char NIC makes a later declare-characteristic
# `duplicate characteristic`. ★The refusal comes BEFORE the property half, so
# the first default survives; a non-constant default is rejected exactly as in
# declare-char-property and then the property is never created, so reading it
# is `unknown character property`. ★These diagnostics point at the FORM, the
# opposite of declare-char-property's. ccp1b is the SAME file without -2: the
# form itself is a keys[] entry and needs no flag — only `#f` for the public
# identifier is dsssl2-only, which is why that one declaration comes last.
# ★The fixture also pins that the five built-in property names the reference
# keys (space? punct? record-end? input-tab? input-whitespace?) are INERT
# above lastSyntacticKey: `space?` is still an ordinary procedure name.

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

run_case() { # name document expected_err [extra-flag] [stylesheet-base]
  local name="$1" doc="$2" experr="$3" flag="${4:-}" dsl="${5:-$1}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" $flag -t sgml -d "$dsl.dsl" "$doc" > "$name.out" 2> "$name.err" )
  compare "$name" "$experr" "$?"
}

# the same, on the `-t fot` backend: the flow object tree goes to the -o file
# (macro4 is there because the sequence bracket and the style of a macro make
# are invisible on the transform sink).
run_fot_case() { # name document expected_err [extra-flag]
  local name="$1" doc="$2" experr="$3" flag="${4:-}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" $flag -t fot -o "$name.out" -d "$name.dsl" "$doc" > "$name.stdout" 2> "$name.err" )
  compare "$name" "$experr" "$?"
}

compare() { # name expected_err rc
  local name="$1" experr="$2" rc="$3"
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
run_case ccp1 propdoc.sgml ccp1.experr -2
run_case ccp1b propdoc.sgml ccp1b.experr "" ccp1
run_case pat1 patdoc.sgml pat1.experr
run_case pat2 patdoc.sgml pat2.experr -2
run_case pat3 patdoc.sgml pat3.experr -2
run_case pat4 patdoc.sgml pat4.experr -2
run_case query1 patdoc.sgml query1.experr
run_case query2 patdoc.sgml query2.experr -2
run_case query3 patdoc.sgml query3.experr
run_case query4 patdoc.sgml query4.experr
run_case query4b patdoc.sgml query4b.experr -2 query4
run_case query5 patdoc.sgml query5.experr
run_case macro1 patdoc.sgml macro1.experr -2
run_case macro1b patdoc.sgml macro1b.experr "" macro1
run_case macro2 patdoc.sgml macro2.experr -2
run_case macro3 patdoc.sgml macro3.experr -2
run_fot_case macro4 patdoc.sgml macro4.experr -2

echo "dazzle-engine: PASS"
