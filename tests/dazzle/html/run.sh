#!/usr/bin/env bash
# tests/dazzle/html/run.sh — the `-t html` backend suite (HtmlFOTBuilder).
#
#   tests/dazzle/html/run.sh [scalyc-binary]
#
# Runs the CLI with `-t html -o out.html` over the fot suite's fixtures
# (shared from ../fot) plus two scroll fixtures of its own, byte-diffing every
# file the run produces — the stylesheet `out.css`, the per-scroll documents
# `out.html`/`out1.html`/… — and the argv0-normalized stderr, against goldens
# produced by the reference C++ dazzle (/usr/local/bin/dazzle, openjade
# 1.3.3-pre1, built with JADE_HTML) — reference-validated 2026-07-30.
#
# The html backend writes a document only for a `scroll` flow object, so the
# fot toys (which use none) exercise the CSS side: the two style tables in
# OpenSP PointerTable iteration order, the class-name/prefix-index machinery,
# outputLength's printf quirks, colour hex, weight/style/align mapping.
# hs1/hs2 add the document side: titles, cross-document and same-document
# links (<A HREF>), anchors (<A NAME>), the <SPAN>/<A> sync state machine,
# multi-document filenames and UTF-8 content.
#
# NOTE (2026-07-30): the dazzledoc DocBook HTML stylesheets additionally need
# four ENGINE primitives we have not ported yet — round, select-by-class,
# follow, entity-system-id — so `dsssl.css` from the html/docbook.dsl run is
# NOT yet byte-identical (four rule families fail to compile and their element
# classes are missing). That is a style-engine gap, not a backend gap.

HERE="$(cd "$(dirname "$0")" && pwd)"
FOT="$(cd "$HERE/../fot" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BIN="${1:-$ROOT/scalyc/build/scalyc}"
cd "$ROOT"
set -u

OUT="$(mktemp -d)/dazzle"
WORK="$(mktemp -d)"
trap 'rm -rf "$(dirname "$OUT")" "$WORK"' EXIT

if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$OUT.build.log" 2>&1; then
  echo "dazzle-html: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

run_case() { # name [document]
  local name="$1" doc="${2:-doc.sgml}"
  local d="$WORK/$name"
  mkdir -p "$d"
  cp "$FOT"/*.sgml "$FOT"/*.dsl "$FOT"/*.scm "$d/" 2>/dev/null
  cp "$HERE"/*.sgml "$HERE"/*.dsl "$HERE"/*.scm "$d/" 2>/dev/null
  ( cd "$d" && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
      "$OUT" -t html -o out.html -d "$name.dsl" "$doc" 2> stderr.raw )
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-html: FAIL $name (rc=$rc)"; cat "$d/stderr.raw"; exit 1
  fi
  sed 's/^[^:]*:/PROG:/' "$d/stderr.raw" > "$d/stderr.log"
  # every golden must match
  for g in "$HERE/$name.css.expected" "$HERE/$name.html.expected" "$HERE/$name.html"[0-9]".expected"; do
    [ -f "$g" ] || continue
    local b
    b="$(basename "$g")"
    b="${b#"$name"}"
    case "$b" in
      .css.expected) b=out.css ;;
      .html.expected) b=out.html ;;
      *) b="out${b#.html}"; b="${b%.expected}.html" ;;
    esac
    if ! diff -q "$g" "$d/$b" > /dev/null 2>&1; then
      echo "dazzle-html: FAIL $name ($b differs)"
      diff "$g" "$d/$b" 2>&1 | head -10
      exit 1
    fi
  done
  # no unexpected extra output files
  local produced
  produced="$(cd "$d" && ls out.css out*.html 2>/dev/null | wc -l | tr -d ' ')"
  local expected
  expected="$(ls "$HERE/$name.css.expected" "$HERE/$name.html.expected" "$HERE/$name.html"[0-9]".expected" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$produced" != "$expected" ]; then
    echo "dazzle-html: FAIL $name (produced $produced files, expected $expected)"
    ( cd "$d" && ls out.css out*.html 2>/dev/null )
    exit 1
  fi
  if [ -f "$HERE/$name.expected.err" ]; then
    if ! diff -q "$HERE/$name.expected.err" "$d/stderr.log" > /dev/null; then
      echo "dazzle-html: FAIL $name (stderr differs)"
      diff "$HERE/$name.expected.err" "$d/stderr.log" | head -10
      exit 1
    fi
  elif [ -s "$d/stderr.log" ]; then
    echo "dazzle-html: FAIL $name (unexpected stderr)"; cat "$d/stderr.log"; exit 1
  fi
}

for n in toy1 toy2 toy3 toy4 toy5 toy6 toy10 toy11 toy12 toy13; do run_case "$n"; done
for n in toy7 toy8 toy9; do run_case "$n" tdoc.sgml; done
for n in bad bad2 bad3 bad6 bad8 bad9 bad10 bad11 bad12; do run_case "$n"; done
for n in bad4 bad5 bad7; do run_case "$n" tdoc.sgml; done
# the scroll fixtures: documents, titles, links, anchors, multi-file output
run_case hs1
run_case hs2
# hs3: the IDREF link arm. This is the only backend that RESOLVES an idref
# address itself (getGroveRoot -> getElements -> namedNode -> elementIndex);
# every step must succeed or the anchor comes out with no HREF. ★namedNode
# folds the query through the instance syntax's subst table, so the
# lower-case `first` finds the element whose ID attribute is FIRST — while
# the name is cut at the first space, an unknown ID and the empty string
# both yield an HREF-less anchor.
run_case hs3

echo "dazzle-html: PASS"
