#!/usr/bin/env bash
# tests/dazzle/fot/run.sh — the `-t fot` backend suite (SgmlFOTBuilder, Inc 8).
#
#   tests/dazzle/fot/run.sh [scalyc-binary]
#
# Builds the CLI and runs it with -t fot over fixture documents, byte-diffing
# the flow-object-tree output (and, for the error fixture, the argv0-normalized
# stderr) against goldens produced by the reference C++ dazzle
# (/usr/local/bin/dazzle, openjade 1.3.3-pre1) — reference-validated 2026-07-27.
#
# Covered: sequence/paragraph/paragraph-break/display-group/line-field flow
# objects, DisplayNIC keywords (keep/keeps/breaks/space-before), inherited
# characteristics (length/length-spec/symbol/bool/string/letter2) incl. the
# millipoint Units quirks (.5pt/-3pt), use: chains, (style ...) values,
# pending <a name=…/> element anchors (ID + element index), text escaping
# (&amp;/&lt; + numeric char refs), the default <docbase>.fot output name, and
# the invalid-value / invalid-keyword diagnostics (make vs style message,
# make-location anchor). toy3/toy4: simple-page-sequence — the six
# header/footer sosofo NICs with the four-page-type dedup (front=/first=
# attributes), page-number-sosofo / current-node-page-number-sosofo, and
# external-procedure (Clark if-first-page / if-front-page + unknown-id -> #f);
# bad2: non-sosofo header/footer values (value-location anchor, process-time
# order after the compile-time keyword message) + left-header: on paragraph.
# toy5/toy6: lazy IC values (VarInheritedC) — inherited-* over initial values,
# pushed specs and nested levels, display-var capture (let-bound var in an IC
# expr), a lazy (style ...) via use:, dimensioned arithmetic on characteristic
# values, actual-* with the depending re-push at a deeper level (toy6's
# display-group re-evaluates the outer font-size) and the circular-use error;
# bad3: inherited-* outside a characteristic value (rule falls back to default
# processing) + the actual-* circularity loop (one message per <p>).
# toy7 (tdoc.sgml): the table family — table/table-part/table-column/table-row/
# table-cell/table-border, table-width (explicit/#f-minimum), the four table
# border NICs with the table-border IC fallback, per-cell cell-*-border
# actuals, column/row styles wrapped in <sequence> (always-attached make
# styles), column-number/n-columns-spanned/n-rows-spanned spans with the
# covered-rowspan fill (synthesized cells incl. the trailing missing dummy),
# starts-row? cells without row FOs (tokenized-attribute pattern match), and
# the table-part principal/header/footer serial decomposition.
# bad4 (tdoc.sgml): constant table NIC errors at COMPILE (value-anchored,
# once: bad border value, column-number 0), table-row/table-cell outside a
# table (location-less, per occurrence, unclosed <table-row> quirk), and a
# non-constant invalid n-rows-spanned (per-process, value-anchored).
# bad6 (doc.sgml): atomicContent (content on make paragraph-break — message
# at the make location, content dropped, the <paragraph-break/> still emitted;
# fires in reverse rule-compile order BEFORE title's const conversion) +
# line-field break-*-priority conversion diagnostics: constant invalid value
# once at compile, non-constant invalid value per process (2 x <p>), valid
# priorities accepted but never printed (startLineField drops its NIC).
# toy9 (tdoc.sgml): label:/content-map: — table-part header/footer ports fed
# by labeled row groups through a content-map (incl. (bd #f) principal
# routing), the nested same-port connection (save-queue replay as a sibling
# in the header), repeated <a> anchors per connection, and default content
# ((make paragraph) with no content = (process-children)).
# bad7 (tdoc.sgml): the connection diagnostics — badContentMap (once per map,
# value-anchored), contentMapBadPort, badConnection (label with no port,
# content follows inline), labelNotASymbol (hard eval error per node, initial-
# mode children fallback), and content-map on a non-ported paragraph
# (rows outside a table).
# toy10 (doc.sgml): the rule flow object (orientation/length/break-*-priority
# NICs; display NICs for the display orientations, inline NICs otherwise),
# fraction-bar (RuleC; the rule class binding as the inherited initial),
# glyph-subst-table (single/list/#f values, gst<n> dedup with the
# <define-glyph-subst-table> stream blocks, inherited-glyph-subst-table
# rewrap) and the glyph-id/glyph-subst-table/glyph-subst primitives — incl.
# the eager top-level define evaluation (canEval) whose order the gst
# numbering observes (dbprint *small-caps* shape).
# bad8 (doc.sgml): the error paths — invalid orientation/length on rule
# (defaults kept: bare <rule orientation="horizontal"/>), content on the
# atomic rule class, invalid fraction-bar / glyph-subst-table characteristic
# values (constants at compile, non-constants per process), and the
# glyph-subst-table/glyph-subst/glyph-id primitive argument errors.
# toy11 (doc.sgml): format-number / format-number-list — letter (a/A incl.
# aa/zz), roman (i/I incl. subtractive forms, |n|>5000 decimal fallback),
# zero-padded decimal widths, negatives, and list forms with string/list
# formats and separators.
# bad9/bad10 (doc.sgml): the format-number error paths — invalidNumberFormat
# is non-fatal (result still emitted), argument type errors abort the rule
# (default-processing fallback), incl. the reference arg-index quirks
# (list-element format/number errors report index 0, an exhausted format
# list reports the remaining tail as "not a list").
# toy12 (doc.sgml): #!optional/#!rest/#!key formals — defaults referencing
# earlier formals (incl. key-arg inits, the reference rest-only init-env
# resize), (lambda x body), repeated keywords (first wins), rest+key combos.
# bad11 (doc.sgml): the call-arity diagnostics — missingArg/tooManyArgs/
# oddKeyArgs fire at COMPILE on constant ops (args truncated, reference
# CallExpression::compile), invalidKeyArg/keyArgsNotKey per process at the
# defining lambda's location (VarargsInsn).
# toy13 (doc.sgml; ext1.dsl/ext2.dsl): external-specification — a CDATA DSSSL
# document entity re-parsed as its own doc, specid= part selection vs the
# first-part form (reference IList prepend: the FIRST-created header),
# cross-doc use= chains, define precedence across parts (earlier part wins
# silently), main-part rule override, external-part element rules.
# bad12 (doc.sgml): duplicateDefinition in the same part (with the
# "first definition was here" auxiliary location line) + a user define
# displacing a builtin (part -1) so the later call reports
# callNonFunction at compile.
# mg1 (doc.sgml, loading mgsub.sgml + mgsub2.sgml): the GROVE INDEX in an
# element name. Every backend prefixes a NON-document grove's index and a dot
# to the anchor / destination it writes (SgmlFOTBuilder::outputElementName;
# grove 0 writes the bare name) — live only since sgml-parse can put a second
# grove in reach. The golden pins a resolved-node link into each of two loaded
# groves and into the document's own, the idref address (whose grove is the
# CURRENT node's, not the target's), and the pending anchors a processed node
# of a loaded grove leaves, by ID and by element index. ★The first LOADED grove
# is index 2: the document grove's own groveTable_ entry is counted first.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "dazzle-fot: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

# inputs are COPIED into a scratch workdir (sweep-harness lesson: outputs must
# never land next to repo fixtures).
cp "$HERE"/*.sgml "$HERE"/*.dsl "$HERE"/*.scm "$WORK/"

run_case() { # name expected [expected_err] [document]
  local name="$1" expected="$2" experr="${3:-}" doc="${4:-doc.sgml}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
      "$OUT" -t fot -o "$name.out.fot" -d "$name.dsl" "$doc" 2> "$name.err" )
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-fot: FAIL $name (rc=$rc)"; cat "$WORK/$name.err"; exit 1
  fi
  if ! diff -q "$expected" "$WORK/$name.out.fot" > /dev/null; then
    echo "dazzle-fot: FAIL $name (fot differs)"
    diff "$expected" "$WORK/$name.out.fot" | head -10
    exit 1
  fi
  if [ -n "$experr" ]; then
    sed 's/^[^:]*:/PROG:/' "$WORK/$name.err" > "$WORK/$name.err.norm"
    if ! diff -q "$experr" "$WORK/$name.err.norm" > /dev/null; then
      echo "dazzle-fot: FAIL $name (stderr differs)"
      diff "$experr" "$WORK/$name.err.norm" | head -10
      exit 1
    fi
  elif [ -s "$WORK/$name.err" ]; then
    echo "dazzle-fot: FAIL $name (unexpected stderr)"; cat "$WORK/$name.err"; exit 1
  fi
}

run_case toy1 "$HERE/toy1.expected"
run_case toy2 "$HERE/toy2.expected"
run_case toy3 "$HERE/toy3.expected"
run_case toy4 "$HERE/toy4.expected"
run_case toy5 "$HERE/toy5.expected"
run_case toy6 "$HERE/toy6.expected" "$HERE/toy6.expected.err"
run_case toy7 "$HERE/toy7.expected" "" tdoc.sgml
run_case toy8 "$HERE/toy8.expected" "" tdoc.sgml
run_case toy9 "$HERE/toy9.expected" "" tdoc.sgml
run_case toy10 "$HERE/toy10.expected"
run_case toy11 "$HERE/toy11.expected"
run_case toy12 "$HERE/toy12.expected"
run_case toy13 "$HERE/toy13.expected"
run_case toy14 "$HERE/toy14.expected"
run_case bad  "$HERE/bad.expected" "$HERE/bad.expected.err"
run_case bad2 "$HERE/bad2.expected" "$HERE/bad2.expected.err"
run_case bad3 "$HERE/bad3.expected" "$HERE/bad3.expected.err"
run_case bad4 "$HERE/bad4.expected" "$HERE/bad4.expected.err" tdoc.sgml
run_case bad5 "$HERE/bad5.expected" "$HERE/bad5.expected.err" tdoc.sgml
run_case bad6 "$HERE/bad6.expected" "$HERE/bad6.expected.err"
run_case bad7 "$HERE/bad7.expected" "$HERE/bad7.expected.err" tdoc.sgml
run_case bad8 "$HERE/bad8.expected" "$HERE/bad8.expected.err"
run_case bad9 "$HERE/bad9.expected" "$HERE/bad9.expected.err"
run_case bad10 "$HERE/bad10.expected" "$HERE/bad10.expected.err"
run_case bad11 "$HERE/bad11.expected" "$HERE/bad11.expected.err"
run_case bad12 "$HERE/bad12.expected" "$HERE/bad12.expected.err"
run_case mg1 "$HERE/mg1.expected"

# default output name: <docbase>.fot in the current directory (JadeApp).
( cd "$WORK" && rm -f doc.fot && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
    "$OUT" -t fot -d toy1.dsl doc.sgml 2> /dev/null )
if ! diff -q "$HERE/toy1.expected" "$WORK/doc.fot" > /dev/null; then
  echo "dazzle-fot: FAIL default-output-name"; exit 1
fi

# The one deliberate deviation of this backend — where a run of adjacent
# <text> elements is broken. Its own script carries the full reasoning and a
# check tight enough that only the boundary may differ.
"$HERE/textrun-deviation.sh" "$OUT" || exit 1

echo "dazzle-fot: PASS"
