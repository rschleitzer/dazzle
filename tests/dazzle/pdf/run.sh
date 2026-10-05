#!/usr/bin/env bash
# tests/dazzle/pdf/run.sh — the `-t pdf` backend suite (PdfFOTBuilder).
#
#   tests/dazzle/pdf/run.sh [scalyc-binary]
#
# Builds the CLI and runs it with -t pdf over the fixtures here, byte-diffing
# the PDF against a golden. There is no reference to take the goldens from —
# jade has no PDF backend — so they are this backend's own output, looked at
# page by page when they were frozen (2026-10-05); what the suite proves is
# that the output does not change unnoticed. The file carries no date and no
# identifier, so the same input gives the same bytes.
#
# book: a small book in two simple page sequences (roman and arabic page
# numbers, the second restarting), headers and footers with the page number,
# a table of contents with leaders and current-node-page-number, headings
# kept with the paragraph after them, justified paragraphs, a numbered list
# set with line fields, a table with a header row repeated on its second
# page, cell backgrounds and borders, verbatim text, a rule and a PNG.
#
# fonts: text in a font family found among the files of DAZZLE_FONTS and
# embedded -- two synthetic fonts whose glyphs are rectangles, a regular and
# a bold one -- with characters far beyond code page 1252 and a composed
# glyph; and a family no file has, which is set in a standard font. `book` runs with DAZZLE_FONTS empty, that is with
# no font files at all, so that it does not depend on the fonts of the
# machine.
#
# To freeze a new golden after a deliberate change: run with BLESS=1.

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
  echo "dazzle-pdf: FAIL (build)"; tail -8 "$OUT.build.log"; exit 1
fi

cp "$HERE"/*.sgml "$HERE"/*.dsl "$HERE"/*.png "$WORK/"
cp -R "$HERE/fonts" "$WORK/fonts"

run_case() { # name [font directories]
  local name="$1"
  ( cd "$WORK" && DAZZLE_FONTS="${2:-}" SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
      "$OUT" -t pdf -o "$name.out.pdf" -d "$name.dsl" "$name.sgml" 2> "$name.err" )
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "dazzle-pdf: FAIL $name (rc=$rc)"; cat "$WORK/$name.err"; exit 1
  fi
  if [ -s "$WORK/$name.err" ]; then
    echo "dazzle-pdf: FAIL $name (unexpected stderr)"; cat "$WORK/$name.err"; exit 1
  fi
  if [ "${BLESS:-}" = 1 ]; then
    cp "$WORK/$name.out.pdf" "$HERE/$name.expected.pdf"
  fi
  if ! cmp -s "$HERE/$name.expected.pdf" "$WORK/$name.out.pdf"; then
    echo "dazzle-pdf: FAIL $name (pdf differs)"
    cmp "$HERE/$name.expected.pdf" "$WORK/$name.out.pdf" | head -3
    exit 1
  fi
}

run_case book
run_case fonts fonts

# default output name: <docbase>.pdf in the current directory.
( cd "$WORK" && rm -f book.pdf && DAZZLE_FONTS= SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
    "$OUT" -t pdf -d book.dsl book.sgml 2> /dev/null )
if ! cmp -s "$HERE/book.expected.pdf" "$WORK/book.pdf"; then
  echo "dazzle-pdf: FAIL default-output-name"; exit 1
fi

# a file that cannot be written is reported, with exit code 1.
( cd "$WORK" && SCALY_HOME="$ROOT" SP_CHARSET_FIXED=YES SP_ENCODING=XML \
    "$OUT" -t pdf -o no-such-directory/book.pdf -d book.dsl book.sgml > /dev/null 2> unwritable.err )
if [ $? -ne 1 ] || ! grep -q "no-such-directory/book.pdf" "$WORK/unwritable.err"; then
  echo "dazzle-pdf: FAIL unwritable output"; cat "$WORK/unwritable.err"; exit 1
fi

echo "dazzle-pdf: PASS"
