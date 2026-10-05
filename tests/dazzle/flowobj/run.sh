#!/usr/bin/env bash
# tests/dazzle/flowobj/run.sh — the FLOW-OBJECT-CLASS suite: one fixture family
# per class bundle, differentially against the
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
# OutputEncoder item, unrelated to this family).
#
# --- the math bundle: math-sequence, fraction, unmath, superscript,
#     subscript, script, mark, fence, radical, math-operator, grid, grid-cell
#     ---------------------------------------------------------------------
#
# math1 (-t fot, -t tex, -t rtf, -t mif): the positive matrix — all twelve
# classes, every port of the six that have them, both counts of grid and
# grid-cell, a `radical:` character and its defaulted form, and the fraction
# bar with and without a fraction-bar style. ★It pins the four things the
# reference decides that no reading of the spec would: `fraction` alone has NO
# principal port, so its unlabelled content lands directly after the bar and
# BEFORE the numerator (pushPorts' hasPrincipalPort argument is a documented
# FIXME the reference never reads); the other five open a `<x.principal>`
# element inside their SERIAL open and close it in their first port bracket;
# `radical.radical` and its defaulted twin BOTH open that principal port; and
# a grid count of zero prints no attribute at all.
#
# math2 (-2, -t fot): the diagnostic matrix — a conversion failure per
# characteristic, the `<= 0` gate of the four grid counts (same diagnostic as
# a type failure), the isCharacter demand of `radical:`, and the
# unknown-keyword message for a class with keywords, a class with different
# ones, and a class with none.
#
# math3 (-t rtf): the RTF backend's own math machinery, which no other golden
# reaches — the EQ field, the three grid positioning modes (including a cell
# with no position, whose content the reference DISCARDS), the grid
# separators and column alignment, `\i\in` for an inline math-operator, the
# three operator glyphs that select `\su`/`\pr`/(nothing) and the `\vc\` any
# other one gets, the EQ escaping of `,` `(` `)` `\` (and the fence
# delimiters that are exempt from it), the sub/superscript and mark
# distances, and the lazy (non-constant) characteristic chain.
#
# math4 (-t sgml): the same matrix on the TRANSFORM backend, where every math
# bracket is a no-op and only the document text survives. Byte-identical to
# the reference on BOTH streams since work package 23 — the transform path
# runs through the same FotSink as the five print backends, so its ports are
# real ports and the `no port for label` flood this golden used to document is
# gone.
#
# --- the layout-composite bundle: embedded-text, included-container-area,
#     side-by-side, side-by-side-item, aligned-column --------------------
#
# layout1 (-t fot, -t tex, -t rtf, -t mif): the positive matrix — all five
# classes, every characteristic each one takes, the lazy (non-constant) chain,
# an inherited characteristic per class (including the family's own three
# side-by-side-* ICs) and the family nested inside itself. ★It pins the one
# initial value in the family that is not "unset": included-container-area's
# scale defaults to max-uniform, so even an untouched one carries a scale
# attribute — and a numeric or paired scale switches it to scale-x/scale-y.
# Only the fot backend overrides any of the five; on tex/rtf/mif the plain
# start()/end() brackets leave nothing but the content.
#
# layout2 (-t fot): the diagnostic matrix — a conversion failure per
# characteristic and the unknown-keyword message per class, including the two
# classes that take a display NIC (where a non-display key is unknown) and
# side-by-side-item, which takes nothing at all. ★Two asymmetries: `#f` is a
# VALID width:/height: (it selects the minimum form) but an INVALID direction:,
# because embedded-text's allowed set deliberately omits symbolFalse. It runs
# WITHOUT -2 on purpose: under -2 the reference coerces a string value into a
# number/symbol/boolean before every characteristic conversion
# (Interpreter::convertFromString), so half these values would convert instead
# of failing. That leniency is ported and has its own matrix in
# tests/dazzle/engine (conv1/conv2); here it would only blunt the diagnostics.
#
# layout3 (-t sgml): the same stylesheet on the transform backend, where all
# five brackets are no-ops and only the document text survives.
#
# layout4 (-t fot, -t rtf): the CAPTURE path — each class inside content that
# is recorded and replayed instead of emitted straight through (a
# simple-page-sequence header, a fraction port, a table-part header). It pins
# that included-container-area's two halves — its own record and the shared
# display NIC — survive the queue together.
#
# --- the online bundle: marginalia, multi-mode -------------------------
#
# online1 (-t fot, -t tex, -t rtf, -t mif): the positive matrix. marginalia is
# a bare bracket whose four characteristics are all INHERITED ones; multi-mode
# is the only class in the port whose PORTS are decided at run time — its
# `multi-modes:` list names them, in all four member shapes (`#f`, a symbol,
# `(#f "desc")`, `(sym "desc")`). ★It pins that the modes replay in the order
# the LIST gives, not the order the content gives; that a mode with no content
# still gets its element; that an empty list is a valid value; and that
# unlabelled content still lands in the enclosing stream when no principal
# mode was asked for (pushPorts' hasPrincipalMode is the same never-read
# argument `fraction` exposes).
#
# online1b (-t fot): ★OUR behaviour. A multi-mode inside another multi-mode's
# NAMED MODE crashes the reference binary — SerialFOTBuilder keeps ONE save_
# list for every open multi-mode (FOTBuilder.cxx:3335), so the outer's replay
# reads a dangling head (measured rc 139, EXC_BAD_ACCESS in
# SerialFOTBuilder::endMultiMode). Nesting inside the PRINCIPAL stream works
# and is in online1.
#
# online2 (-t fot): the diagnostic matrix — every malformed shape of a
# `multi-modes:` member. ★The first bad member messages and STOPS, so the
# modes collected before it survive into the dump.
#
# online3 (-t sgml): the multi-mode matrix on the TRANSFORM backend, and the
# fixture that USED to document the transform-path gap — its stdout diverged
# (the reference replays the modes in list order, this port left the content
# where it stood) and its stderr carried nine `no port for label` lines the
# reference never raised. Work package 23 closed both: the golden is now
# minted from the reference, on both streams. ★It is therefore a real
# DISCRIMINATOR, not just a guard — reverting the FotSink seam brings the nine
# lines and the swapped mode order straight back.
#
# --- the page/column model: page-sequence, column-set-sequence ---------
#
# pagecol1 (-t fot, -t tex, -t rtf, -t mif): the positive matrix of the last
# two classes of the reference's registry. Both are plain compound brackets,
# so the contract is which characteristics each one takes: ★`page-sequence`
# has NO hasNonInheritedC at all — its six (page-category, force-last-page,
# force-first-page, first-page-type, justify-spread?, binding-edge) are
# INHERITED characteristics that reach the backend through the ics buffer —
# while `column-set-sequence` carries a bare display NIC, exactly like
# `aligned-column`. Only the fot backend overrides either; on tex/rtf/mif the
# plain start()/end() brackets leave nothing but the content. ★It also pins
# the reference's own typo: `justify-spread?` prints as `jystify-spread`.
#
# pagecol2 (-t fot): the diagnostic matrix — the unknown-keyword message for
# a class with no keywords at all (a display key on `page-sequence` is
# unknown, though its sibling accepts it) and a conversion failure per
# characteristic. ★`first-page-type: #t` is NOT a failure: #t is a c-value
# symbol, so it converts and prints `first-page-type="true"`. Like layout2 it
# runs WITHOUT -2, because the reference's convertFromString coercion is
# still an open item of the Convert layer.
#
# pagecol3 (-t sgml): the same stylesheet on the transform backend, where
# both brackets are no-ops and only the document text survives.
#
# pagecol4 (-t fot, -t rtf): the CAPTURE path — both classes inside content
# that is recorded and replayed (a simple-page-sequence header, a fraction
# port, a table-part header), so `column-set-sequence`'s display NIC has to
# survive the queue and `page-sequence` records a payload-less bracket.
#
# --- the address family (the addresses cluster) ---
#
# addr1 (-t fot, addrdoc.sgml): the VALUE side — the seven producers, what
# address? says about each, and how address-local? and address-visited?
# classify all six reachable types. ★address-local? is #t for a resolved node
# (sameGrove is groveIndex == groveIndex, and this engine has ONE grove) and
# for ANY idref, even one no element carries — it never resolves; #f for an
# entity reference and for everything the switch does not name. ★#f is not an
# address: the link characteristic maps it to Address::none, the predicate
# says no. ★`equal?` has no address arm, so two addresses of the same node
# are not equal.
#
# addr2 (-t fot, addrdiag.sgml): the DIAGNOSTIC side — ONE probe per element,
# because a primitive argError kills the whole construction rule and a second
# probe in the same rule is never reached. Covers notAnAddress, notAString on
# both arguments of sgml-document-address, notASingletonNode, and the two
# producers whose only diagnostic is noCurrentNode (forced through a
# top-level define, which is why their locations are the define's).
# ★The reference prints an argument with no printed form of its own as
# `#<unknown object <pointer>>`, so the harness normalizes that number.
#
# addr3 (-t fot / tex / rtf, addrdoc.sgml): the RENDERING side — one link per
# Address type, plus the resolvedNode fork walked over three p's (two with an
# ID, one without). ★The three backends disagree on purpose: fot writes the
# WHOLE idref string as destination= (`alpha beta`), rtf and mif cut at the
# first space, tex sets \Label to the whole string too. ★An idref is NEVER
# namecase-folded on the way out — `destination="alpha"` for the idref of the
# element whose resolved-node form prints `ALPHA`. ★tex is the only backend
# that says anything about the types it cannot render: four warnings, one
# each for a non-element node, an entity, an SGML document and a HyTime
# linkend (the tei and html arms are unreachable — no primitive builds them).
#
# addr3m (-t mif) runs addr3m.dsl, which is addr3 MINUS the non-element
# resolvedNode probe: MifFOTBuilder::startLink pushes no link-stack frame on
# that path (its resize sits inside `if (elementIndex(n) == accessOK)`), so
# endLink trips `assert(linkStack.size() > 0)` and the reference dies with
# SIGABRT — measured rc 134. This port pushes unconditionally and survives;
# a golden minted from a crash is worth nothing, so that probe is left to the
# other backends and the divergence is recorded here.
#
# The html backend's idref arm — the only one that RESOLVES the name, through
# getGroveRoot/getElements/namedNode — is pinned by ../html/hs3, which owns
# that backend's file goldens.
#
# emph1 (-t fot): ★OUR behaviour. `emphasizing-mark` cannot run in the
# reference binary at all — its copy constructor copies nic_ and forgets
# emphmark_ (style/EmphasizingMark.h:28), so every make of the class
# dereferences an indeterminate SosofoObj*; measured rc 138/139 on all six
# backends, with and without a mark:. The golden is the emission the
# reference's own SerialFOTBuilder/SgmlFOTBuilder code is written for.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
. tests/toolchain.sh "${1:-}" || exit 2
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" > "$OUT.build.log" 2>&1; then
  echo "dazzle-flowobj: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

cp "$HERE"/*.sgml "$HERE"/*.dsl "$WORK/"

# a backend whose tree goes to the -o file (fot/tex/rtf/mif/html)
run_case() { # name backend [extra-flag] [stylesheet-base] [document]
  local name="$1" backend="$2" flag="${3:-}" dsl="${4:-$1}" doc="${5:-fodoc.sgml}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" $flag -t "$backend" -o "$name.out" -d "$dsl.dsl" "$doc" \
      > "$name.stdout" 2> "$name.err" )
  compare "$name" "$name.out" "$?"
}

# the transform backend writes the instance to STDOUT
run_transform_case() { # name [extra-flag] [stylesheet-base] [document]
  local name="$1" flag="${2:-}" dsl="${3:-$1}" doc="${4:-fodoc.sgml}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" $flag -t sgml -d "$dsl.dsl" "$doc" \
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
  # PROG: for the argv[0] prefix, and ADDR for the raw pointer the reference
  # prints when an object has no printed representation of its own
  # (`#<unknown object %lu>`, ELObj::print's default) — an allocation address,
  # so it differs between binaries and between runs of the same binary.
  sed -e 's/^[^:]*:/PROG:/' -e 's/unknown object [0-9][0-9]*/unknown object ADDR/g' \
    "$WORK/$name.err" > "$WORK/$name.err.norm"
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

# the math bundle: the positive matrix on each of the four backends that write
# a tree to -o, then the diagnostics, the RTF machinery and the transform run.
run_case math1 fot
run_case math1t tex "" math1
run_case math1r rtf "" math1
run_case math1m mif "" math1
run_case math2 fot -2
run_case math3 rtf
run_transform_case math4

# the layout-composite bundle: the positive matrix on the four -o backends,
# the diagnostics, the transform run and the capture path.
run_case layout1 fot
run_case layout1t tex "" layout1
run_case layout1r rtf "" layout1
run_case layout1m mif "" layout1
run_case layout2 fot
run_transform_case layout3 "" layout1
run_case layout4 fot
run_case layout4r rtf "" layout4

# the online bundle
run_case online1 fot
run_case online1t tex "" online1
run_case online1r rtf "" online1
run_case online1m mif "" online1
run_case online1b fot
run_case online2 fot
run_transform_case online3 "" online1

# the page/column model: the positive matrix on the four -o backends, the
# diagnostics, the transform run and the capture path.
run_case pagecol1 fot
run_case pagecol1t tex "" pagecol1
run_case pagecol1r rtf "" pagecol1
run_case pagecol1m mif "" pagecol1
run_case pagecol2 fot
run_transform_case pagecol3 "" pagecol1
run_case pagecol4 fot
run_case pagecol4r rtf "" pagecol4

# the ADDRESS family: the value side, the diagnostics, and the link
# rendering of every Address type on four of the five link-aware backends
# (html is in ../html/hs3, which owns that backend's file goldens).
run_case addr1 fot "" addr1 addrdoc.sgml
run_case addr2 fot "" addr2 addrdiag.sgml
run_case addr3 fot "" addr3 addrdoc.sgml
run_case addr3t tex "" addr3 addrdoc.sgml
run_case addr3r rtf "" addr3 addrdoc.sgml
run_case addr3m mif "" addr3m addrdoc.sgml

# the EXTENSION CHARACTERISTICS: all sixteen names
# of the four backend tables, declared in one stylesheet and set on both a
# page sequence and a paragraph, then rendered on three backends. The three
# that appear in no other fixture are here: `preserve-sdata?` and the two
# OpenJade-prefixed ones, `page-two-side?` / `two-side-start-on-right?` —
# the only extension characteristics whose public id is not in the James
# Clark namespace, and TeX-only (an earlier COMPLETENESS note filed them
# under RTF). The sixteenth, `scroll-title`, is html-only and lives in
# ../html/hs1. ★The rtf and mif runs are the contrast: resolution is by
# PUBLIC ID against the ACTIVE backend's table, so the same declarations that
# steer TeX are plain IgnoredCs there — accepted, rendering nothing — exactly
# like the made-up public id this stylesheet also declares.
run_case xchar1 tex
run_case xchar1r rtf "" xchar1
run_case xchar1m mif "" xchar1

# --- the TRANSFORM PATH itself (work package 23) --------------------------
#
# trans1 (-t sgml): the PORT ORDER matrix. Every multi-port class is written
# with its labelled children BEFORE the unlabelled content, so the principal
# content has to come out first and the ports in PORT-DECLARATION order, not
# in source order. ★This is the DISCRIMINATOR for the whole package: before
# the transform path ran through the FotSink, this port replayed the children
# where they stood and drew a `no port for label` per label. It also pins that
# a label with NO port still messages here, and that the table decomposition
# reaches the transform sink.
#
# trans1b (-t sgml): ★OUR behaviour. `emphasizing-mark` is the one port class
# the reference binary cannot survive on this backend (see the stylesheet's
# own header for the reference line) — alone it silently loses the flow
# object, with a sibling after it it SEGFAULTS (rc 139).
#
# trans2 (-t sgml): the STYLE SEAM. FlowObj::process pushes the attached style
# on every backend, so a LAZY characteristic evaluates and its failure is
# reported even though no setter renders anything. ★Four `car` failures, one
# per lazy site — including one on the transform backend's OWN `element`
# class, which is what forced that class onto the styled make path (its
# hasNIC claims only `gi`/`attributes`, everything else is an inherited
# characteristic). `use:`, the actual-* circularity and the eager conversion
# diagnostics ride along in reference order.
#
# trans3 (-t sgml): the transform classes THROUGH A CAPTURED PORT. A `label:`ed
# child is recorded onto a save queue and replayed when its owner flushes, so
# element brackets, attribute lists, entity refs, PIs and the formatting
# instruction all have to survive the round trip — and come back in port
# order, before the principal stream's own copies.
run_transform_case trans1
run_transform_case trans1b
run_transform_case trans2
run_transform_case trans3

echo "dazzle-flowobj: PASS"
