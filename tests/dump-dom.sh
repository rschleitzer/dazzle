#!/bin/bash
# Load a page in headless Chrome and write the DOM it ends with.
#
#   tests/dump-dom.sh <chrome> <profile-dir> <url> <dom-file> <stderr-file>
#
# Chrome writes the DOM and is then meant to end. It does not always: with a
# fresh profile its updater can keep the process alive for as long as nobody
# ends it, the DOM long written -- a suite waiting for the exit waits for
# ever. So Chrome runs beside this script, which waits for the exit OR for a
# DOM that is complete and has stopped growing, and ends what is left.
# Answers 0 where a DOM was written, 1 where Chrome wrote none in three
# minutes.
chrome=$1; profile=$2; url=$3; dom=$4; err=$5
"$chrome" --headless=new --disable-gpu --no-first-run --user-data-dir="$profile" \
  --virtual-time-budget=60000 --dump-dom "$url" > "$dom" 2> "$err" &
pid=$!
complete=0
for _ in $(seq 360); do
  kill -0 "$pid" 2>/dev/null || break
  if grep -q '</html>' "$dom" 2>/dev/null; then
    # written to its last line: two looks in a row, then Chrome is not waited for
    complete=$((complete + 1))
    [ "$complete" -ge 4 ] && break
  fi
  sleep 0.5
done
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid" 2>/dev/null
  sleep 0.5
  kill -9 "$pid" 2>/dev/null
fi
wait "$pid" 2>/dev/null
grep -q '</html>' "$dom" 2>/dev/null
