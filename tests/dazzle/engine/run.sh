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

# key3 (keydoc.sgml): the LAST FOUR keys[] names this port had never
# installed — `data` (formatting-instruction's one characteristic and the
# only hasNonInheritedC in the reference that tests a key for it), `open` and
# `close` (multi-line-inline-note's two ports; that CLASS is commented out of
# installFlowObjs and deliberately not ported, its keys are installed all the
# same) and `null` (node-property's third keyword argument). ★None of them
# belongs to the page/column model, where an earlier COMPLETENESS note had
# grouped them. All four sit far above lastSyntacticKey and every consumer on
# this side reaches them by NAME, so installing them was measured NOT
# observable — this fixture is the guard that it stays that way: they remain
# ordinary variable, procedure and let-binding names, `data:` still reaches
# the formatting instruction, `null:` still reaches node-property, and all
# four are still `not a valid keyword` on a class that does not name them
# (a name with no key at all gives the identical message, measured).

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

# lang1 / lang2 (propdoc.sgml): define-language and its COLLATION half
# (style/LangObj.cxx). lang1 is the positive matrix - the collating order,
# multi-collating elements, collating symbols, per-level weights (including a
# string weight, which contributes one weight per CHARACTER), the #t default
# position, backward and position levels, the case tables and with-language /
# current-language / declare-default-language. ★A language with no `collate`
# clause has ZERO levels, so compare() answers 0 for every pair: string<? is
# #f and string<=? #t whatever the code points say. ★An unknown character has
# no weights, atLevel stops at the first miss, and the SHORTER level string
# sorts FIRST - `(string<? "z" "a")` is #t in a language that orders only
# a b c. lang2 is the failure side: the only two diagnostics the form can
# produce (syntacticKeywordAsVariable, duplicateDefinition with its auxiliary
# line - and the duplicate FAILS the form, so the first language survives),
# the silent failures (unknown clause key, unknown collate sub-key, an
# undeclared multi-character position, and ★a (forward) level followed by a
# (backward) one, because the reference's LevelSort accumulator is never
# reset between levels), and that the seven new keys are inert outside the
# form - collate/toupper/tolower/symbol/order/forward/backward are ordinary
# variable and procedure names.

# conv1 / conv1b / conv2 / conv2b (keydoc.sgml, -t fot): the `-2` STRING
# LENIENCY of the characteristic converters (Interpreter::convertFromString,
# Interpreter.cxx:1095) - COMPLETENESS.md gap (12). Under -2 every
# characteristic value goes through it before its converter, so a STRING may
# stand in for the number, symbol or boolean that converter wants; without
# the flag the function is a no-op, which is why each stylesheet runs twice
# and the b-goldens are almost entirely `invalid value`. The matrix runs over
# the CONVERSION KINDS, not over the classes: the hints belong to the
# converter (a union over all three would reinterpret a genuine string
# characteristic, so `data: "5"` and `font-name: "12"` must stay strings).
# conv1 covers the inherited side plus the shared display NIC - boolean,
# integer with convertNumber's whole syntax (#x48, +9, -4), length,
# length-spec, enum, real, and the two OPTIONAL forms whose leniency runs
# BEFORE their #f test (expand-tabs?, min-leading, inline-space-space).
# conv2 covers the per-class NIC records: the layout composite (the two
# repros that measured the gap), the character NIC, rule, table-column,
# table-cell, box/score/leader and the page/column model.
# *Three measured details the goldens pin: case is NOT folded ("YES" is
# invalid, the reference's own FIXME); the symbol half is a LOOKUP in the
# symbol table and takes only a name that carries a c-value, so
# `scale: "max-uniform"` stays a string while `quadding: "center"` converts;
# and the number arm resolves quantities right there, so `space-before:
# "3zz"` messages `quantity "zz" undefined` before the invalid value.
# *conv1 also pins a quirk that is NOT about -2 at all and that this port
# was missing: convertLengthSpec/convertLengthC hand the CALLER's field to
# quantityValue, which stores the exact value before anyone checks the
# DIMENSION - so a dimensionless `space-before: 12` messages `invalid value`
# AND prints `.012pt,0pt,0pt`, the partial write left in the NIC.

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
run_fot_case() { # name document expected_err [extra-flag] [stylesheet-base]
  local name="$1" doc="$2" experr="$3" flag="${4:-}" dsl="${5:-$1}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" $flag -t fot -o "$name.out" -d "$dsl.dsl" "$doc" > "$name.stdout" 2> "$name.err" )
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
run_case key3 keydoc.sgml key3.experr
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
run_case lang1 propdoc.sgml lang1.experr
run_case lang2 propdoc.sgml lang2.experr
run_fot_case conv1 keydoc.sgml conv1.experr -2
run_fot_case conv1b keydoc.sgml conv1b.experr "" conv1
run_fot_case conv2 keydoc.sgml conv2.experr -2
run_fot_case conv2b keydoc.sgml conv2b.experr "" conv2

# diag1..diag6b (diagdoc.sgml): the DAZZLE-SIDE MESSAGE AUDIT of 2026-08-08.
# ★These are the only fixtures in this tree whose point is that stderr is NOT
# empty. Every one of them ran byte-identically on stdout before the audit and
# said NOTHING on stderr where the reference reports — the class the audit was
# named after ("a check whose failure branch is silent"), found by walking the
# generated message catalog for accessors with no caller. Two of them are not
# diagnostics at all: diag4's stylesheet used to recurse until the stack gave
# out (rc 139, no output), and diag6/diag6b pin OUTPUT, because `(id …)` was
# not ported in any position.
run_case diag1  diagdoc.sgml diag1.experr
run_case diag1b diagdoc.sgml diag1b.experr
run_case diag1c diagdoc.sgml diag1c.experr
run_case diag2  diagdoc.sgml diag2.experr -2
run_case diag2b diagdoc.sgml diag2b.experr -2
run_case diag2c diagdoc.sgml diag2c.experr -2
run_case diag2d diagdoc.sgml diag2d.experr -2
run_case diag3  diagdoc.sgml diag3.experr
run_case diag3b diagdoc.sgml diag3b.experr
run_case diag3c diagdoc.sgml diag3c.experr
run_case diag4  diagdoc.sgml diag4.experr
run_case diag5  diagdoc.sgml diag5.experr
run_case diag5b diagdoc.sgml diag5b.experr
run_case diag6  diagdoc.sgml diag6.experr
run_case diag6b diagdoc.sgml diag6b.experr

# diag7..diag7c: the LAST site of the audit's class, and it has the other form
# — not a missing message but a missing CHECK. Seven reference DEFPRIMITIVEs
# begin with `if (!context.processingMode)`; this port had the guard on four
# of them and let process-children, process-children-trim and
# process-node-list build a sosofo with a NULL mode instead. ★diag7's third
# line is an ORDER probe: the mode test runs BEFORE the argument test, so
# `(process-node-list 42)` outside a rule reports the CONTEXT — diag7b is the
# control that shows the same call inside a rule reporting the ARGUMENT.
# ★★★diag7c is the one that matters: it pins the OUTPUT. A sosofo with a null
# mode is not an inert error, it PROCESSES — measured `oneonetwotwo` against
# the reference's `onetwo` — so this was never a diagnosis-only gap, and the
# .expected file is what proves it (the other two are stderr-only).
run_case diag7  diagdoc.sgml diag7.experr
run_case diag7b diagdoc.sgml diag7b.experr
run_case diag7c diagdoc.sgml diag7c.experr

# decl1..decl4 (diagdoc.sgml): the DECLARATION PHASE of the specification
# (StyleEngine.cxx:40-80), gathered by DssslSpecEventHandler since forever and
# never executed until 2026-08-08. decl1 is the DOC-level list, decl2 the
# PART-level one plus the map-sdata-entity that motivates the two phases,
# decl3 add-name-chars WITH its control decl3b (same stylesheet, declaration
# removed - without it `a@b` is not an identifier, which is what the fixture
# proves), decl4 the reference's `default:` warning.
# ★Keep these files pure ASCII. A `.dsl` is read as SGML in an 8-bit charset,
# so one multi-byte character in a COMMENT makes the reference report
# `non SGML character number ...` and the whole comparison is about that
# instead - it cost a mint cycle here.
run_case decl1  diagdoc.sgml decl1.experr
run_case decl2  diagdoc.sgml decl2.experr
run_case decl3  diagdoc.sgml decl3.experr
run_case decl3b diagdoc.sgml decl3b.experr
run_case decl4  diagdoc.sgml decl4.experr

# style1..style5 (diagdoc.sgml, -t fot): DSSSL2 STYLE RULES - the last open
# item of the 2026-08-08 message audit. A rule body that starts with a KEYWORD
# sets characteristics instead of building a flow object.
# ★style2 pins the ORDER of equally specific style rules, which IS a contract
# here and is not one for construction rules: every matching style rule
# applies. The reference keeps element rules in an IList that PREPENDS, so the
# run is LAST-DECLARED-FIRST - measured, not assumed.
# ★style3 is `ambiguousStyle`, which was unreachable until these landed.
# ★style5 has no style rule at all: it pins the CheckSosofoInsn that
# Action::compile puts on a CONSTRUCTION rule (and must not put on a style
# rule) - the same line, so it belongs to this batch.
run_fot_case style1 diagdoc.sgml style1.experr -2
run_fot_case style2 diagdoc.sgml style2.experr -2
run_fot_case style3 diagdoc.sgml style3.experr -2
run_fot_case style4 diagdoc.sgml style4.experr -2
run_fot_case style5 diagdoc.sgml style5.experr

echo "dazzle-engine: PASS"
