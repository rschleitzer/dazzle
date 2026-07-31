#!/usr/bin/env bash
# tests/dazzle/grove/run.sh — the GROVE suite: node classes, axes and node
# properties, differentially against the reference C++ dazzle.
#
#   tests/dazzle/grove/run.sh [scalyc-binary]
#
# Home of the COMPLETENESS.md work-package-1 fixtures (the grove property axis).
# Every golden here is minted from /usr/local/bin/dazzle — these cases cover
# grove semantics that no corpus document exercises, so the reference binary is
# the only oracle.
#
# axis1 (doc.sgml): the DSSSL parent AXIS vs the structural (origin) edge.
# ChunkNode::getParent returns accessNull for every node whose origin is the
# grove root, so `parent`, `ancestor`, `have-ancestor?` and the pattern
# ancestor walk stop at the document ELEMENT, while `origin`, `grove-root`,
# `tree-root` and the sibling axes still see the sgml-document node. The golden
# pins all ten values for the grove root, the document element, a nested title
# and a doubly-nested em.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "dazzle-grove: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

# inputs are COPIED into a scratch workdir (outputs must never land next to the
# repo fixtures).
cp "$HERE"/*.sgml "$HERE"/*.dsl "$HERE"/*.scm "$WORK/"

run_case() { # name expected [expected_err] [document]
  local name="$1" expected="$2" experr="${3:-}" doc="${4:-doc.sgml}"
  ( cd "$WORK" && SCALY_HOME="$ROOT" \
      "$OUT" -t sgml -d "$name.dsl" "$doc" > "$name.out" 2> "$name.err" )
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-grove: FAIL $name (rc=$rc)"; cat "$WORK/$name.err"; exit 1
  fi
  if ! diff -q "$expected" "$WORK/$name.out" > /dev/null; then
    echo "dazzle-grove: FAIL $name (output differs)"
    diff "$expected" "$WORK/$name.out" | head -14
    exit 1
  fi
  if [ -n "$experr" ]; then
    sed 's/^[^:]*:/PROG:/' "$WORK/$name.err" > "$WORK/$name.err.norm"
    if ! diff -q "$experr" "$WORK/$name.err.norm" > /dev/null; then
      echo "dazzle-grove: FAIL $name (stderr differs)"
      diff "$experr" "$WORK/$name.err.norm" | head -10
      exit 1
    fi
  elif [ -s "$WORK/$name.err" ]; then
    echo "dazzle-grove: FAIL $name (unexpected stderr)"; cat "$WORK/$name.err"; exit 1
  fi
}

# chars1 (doc.sgml): per-character grove nodes. The reference's DataNode is a
# (chunk, index) view, so `First <em>inner</em> text.` has 13 children and 18
# descendants; the golden pins the class name (data-char), the leaf shape, the
# `char` property, the one-character `data` of a member against the chunk-wise
# `data` of the whole list, the character-counting follow/preced, (chunk, index)
# identity across two children calls, and that processing such a node-list stays
# CHUNK-WISE (each run emitted once, not once per character).
# chars2 (doc.sgml): node-list navigation ACROSS data-chunk boundaries — the
# contract the LAZY node-list representation has to keep. Where chars1 pins the
# per-character node itself, chars2 pins what happens once a walk lands INSIDE
# a run: node-list-rest stepping character by character through a chunk,
# node-list-ref addressing a position that has no member of its own, `data`
# over a partially consumed first member, select-elements skipping a chunk it
# starts in the middle of, follow from a mid-chunk position, and descendants
# order across the boundaries (including the reference's double `inner` — the
# em element contributes its content AND its own character nodes follow).
# props1 (props.sgml): the CLASS METADATA and the intrinsic node properties.
# One report per node class — grove root, prolog PI, epilog PI, document
# element, nested element, EMPTY element, CONREF element, an INCLUDED element,
# a data-char node — of every property the four ported classes declare, with
# null: and default: BOTH supplied so each line discriminates accessOK from
# accessNull from accessNotInClass. It pins: the ClassDef tables
# (children/data/data-sep-property-name, subnode- and all-property-names in
# reference ORDER), that `rcs?: #t` switches every component-name result to the
# short RCS spelling and that an RCS name resolves as a property name,
# case-insensitive lookup, the three-way
# origin-to-subnode-rel-property-name (content / document-element / prolog /
# epilog) and the rsiblings that reads it, `content` being element-only and
# accessOK-even-when-empty, gi/id/included?/must-omit-end-tag?, prolog/epilog,
# the EMPTY children axis of the grove root (kids/desc/data) — and
# select-by-class over both spellings of a class name.
# props2 (attrs.sgml): the ATTRIBUTE axis — the `attributes` named-node-list
# and the attribute-assignment / attribute-value-token node classes, over an
# ATTLIST that covers every declared-value and default-value type: CDATA
# specified / defaulted / #FIXED, an enumeration default, ID, IDREFS, NMTOKENS,
# NUMBER, #CURRENT, ENTITY, ENTITIES and NOTATION, each on a specified AND an
# unspecified element. It pins that the list holds every DECLARED attribute in
# declaration order under its normalized (upper-cased) name; that `implied?` is
# the #IMPLIED-with-no-value test (a DEFAULTED attribute is #f); that
# `token-sep` is a space only for the MULTI-token declared values and accessNull
# everywhere else; that `value` is a data-char run for CDATA but one
# attribute-value-token per token otherwise, accessNull when implied; that the
# reference answers `attribute-def` with accessNotInClass although it LISTS it;
# that a token's `entity` / `notation` / `referent` resolve to nodes (referent
# only for an IDREF that hits); and the data/children shape of both classes.
# props3 (decls.sgml): the remaining NAMED NODE LISTS and every DECLARATION
# node class they hand out. The document declares three notations (PUBLIC /
# SYSTEM / both, one with a #NOTATION ATTLIST), an internal / external / NDATA /
# PI / CDATA / SDATA general entity, a parameter entity, a #DEFAULT entity, and
# element types over every declared content (model group with nested groups and
# both connectors, ANY, CDATA, EMPTY), with inclusions, exclusions, both
# omitted-tag flags, IDs and a #CURRENT attribute shared by two element types.
# It pins: `elements` (keyed by ID VALUE, document order), `entities` /
# `general-entities` / `parameter-entities` / `notations` / `element-types` /
# `defaulted-entities` / `doctypes-and-linktypes` in the reference's HASH-BUCKET
# order with the right substitution table per list (entity names unfolded,
# everything else upper-cased); the document-type, entity, default-entity,
# notation, external-id, element-type, attribute-def, model-group,
# element-token, pcdata-token and sgml-constants classes with their ClassDef
# tables and every property; that a declaration node has NO parent axis and no
# siblings while its grove-root still reaches the sgml-document node; that an
# attribute-def's `origin` is an attribute-def AGAIN (makeOriginNode); that a
# defaulted entity's origin is the sgml-document node and a parameter entity's
# is the doctype; the entity-origin attribute assignments of an NDATA entity;
# and node identity (same2 over the underlying declaration object) across
# separate accesses.
# ★TWO DEVIATIONS are pinned with OUR value, both measured, both in
# COMPLETENESS.md: `tokens` of a NOTATION / name-token-group attribute-def (the
# reference builds its GroveStrings from a LOCAL AttributeDefinitionDesc and
# prints freed memory), and `current-group`, which null-derefs in the reference
# for any DTD with an element type that has no attribute definition list — the
# fixture document gives every element type an ATTLIST so the property is
# measurable at all.
# props4 (appinfo.sgml): `application-info`, which needs an SGML DECLARATION
# with APPINFO to be anything but accessNull.
run_case axis1 "$HERE/axis1.expected"
run_case chars1 "$HERE/chars1.expected"
run_case chars2 "$HERE/chars2.expected"
run_case props1 "$HERE/props1.expected" "" props.sgml
run_case props2 "$HERE/props2.expected" "" attrs.sgml
run_case props3 "$HERE/props3.expected" "" decls.sgml
run_case props4 "$HERE/props4.expected" "" appinfo.sgml

echo "dazzle-grove: PASS"
