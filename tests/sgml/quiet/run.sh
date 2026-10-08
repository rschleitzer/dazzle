#!/usr/bin/env bash
# tests/sgml/quiet/run.sh — `onsgmls -s`: the parse without its ESIS.
#
#   tests/sgml/quiet/run.sh <onsgmls-binary>
#
# With -s the writer renders nothing (ParserState.esis_discard) — it used to
# render every event and drop the text. What must stay exactly as it is
# without the option: the messages and the exit code, for a document that is
# valid and for one that is not; and nothing may reach standard output.
set -u
BIN="${1:?usage: tests/sgml/quiet/run.sh <onsgmls-binary>}"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

printf '<!DOCTYPE doc [<!ELEMENT doc - - (p+)><!ELEMENT p - - (#PCDATA)><!ATTLIST p id ID #IMPLIED>]>\n<doc><p id="a">one</p><p>two &#38; three</p></doc>\n' > "$W/good.sgm"
printf '<!DOCTYPE doc [<!ELEMENT doc - - (p+)><!ELEMENT p - - (#PCDATA)><!ATTLIST p id ID #IMPLIED>]>\n<doc><p id="a">one</p><q>two</q><p id="a">three</p></doc>\n' > "$W/bad.sgm"

fail=0
for d in good bad; do
  ( cd "$W" && "$BIN" "$d.sgm" > "$d.esis" 2> "$d.err" ); rc=$?
  ( cd "$W" && "$BIN" -s "$d.sgm" > "$d.quiet" 2> "$d.quiet.err" ); qrc=$?
  if [ "$rc" != "$qrc" ]; then echo "  $d: exit $qrc with -s, $rc without"; fail=1; fi
  if ! cmp -s "$W/$d.err" "$W/$d.quiet.err"; then echo "  $d: other messages with -s"; fail=1; fi
  if [ -s "$W/$d.quiet" ]; then echo "  $d: -s wrote $(wc -c < "$W/$d.quiet") bytes"; fail=1; fi
  if [ ! -s "$W/$d.esis" ]; then echo "  $d: no ESIS without -s"; fail=1; fi
done
# the two fixtures are what they are meant to be
grep -q '^C$' "$W/good.esis" || { echo "  good: not conforming"; fail=1; }
[ -s "$W/bad.err" ] || { echo "  bad: no message"; fail=1; }

if [ "$fail" != 0 ]; then echo "quiet: FAIL"; exit 1; fi
echo "quiet: PASS (2 documents, with and without -s)"
