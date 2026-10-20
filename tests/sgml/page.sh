#!/usr/bin/env bash
# tests/sgml/page.sh — the parser's web page, in a browser.
#
#   tests/sgml/page.sh [scalyc-binary]
#
# Builds the page (web/onsgmls/build.sh, into a scratch directory), serves it
# over HTTP on a free local port and loads tests/sgml/page/check.html in
# headless Chrome. That page drives web/onsgmls/index.html in a frame as a
# reader does -- the document it opens with, then one the DTD does not allow
# with `-t out.rast`, then the DTD changed in its own tab -- and writes one
# line per check, which this script reads from the DOM Chrome dumps.
# tests/sgml/wasm.sh runs the whole corpus through the page's host; this is
# the page itself.
#
# Needs a wasi-sdk, python3 and Chrome ($CHROME, else Google Chrome or
# Chromium where it is usually installed); SKIPPED by name without them.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

chrome="${CHROME:-}"
if [ -z "$chrome" ]; then
  for cand in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
              "/Applications/Chromium.app/Contents/MacOS/Chromium" \
              "$(command -v google-chrome 2>/dev/null)" "$(command -v chromium 2>/dev/null)" \
              "$(command -v chromium-browser 2>/dev/null)"; do
    [ -n "$cand" ] && [ -x "$cand" ] && { chrome="$cand"; break; }
  done
fi
[ -n "$chrome" ] || { echo "page: SKIP (no Chrome: set CHROME)"; exit 0; }
PY=$(command -v python3 || command -v python) || { echo "page: SKIP (no python3 to serve the page)"; exit 0; }

TMP="$(mktemp -d)"
server=
trap '[ -n "$server" ] && kill "$server" 2>/dev/null; rm -rf "$TMP"' EXIT
web/onsgmls/build.sh "$TMP/www" "${1:-}" > "$TMP/build.out" 2>&1
case $? in
  0) ;;
  3) echo "page: SKIP ($(tail -1 "$TMP/build.out"))"; exit 0 ;;
  *) cat "$TMP/build.out"; exit 1 ;;
esac
cp web/onsgmls/index.html tests/sgml/page/check.html "$TMP/www/" || exit 1

# a free port: the server binds port 0 and writes the one it got
"$PY" -u -c '
import functools, http.server, sys
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=sys.argv[1])
handler.func.log_message = lambda *args: None
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
print("port", server.server_address[1])
server.serve_forever()
' "$TMP/www" > "$TMP/server.out" 2>&1 &
server=$!
disown "$server"
port=
for _ in $(seq 100); do
  port=$(sed -n 's/^port \([0-9][0-9]*\)$/\1/p' "$TMP/server.out" 2>/dev/null | head -1)
  [ -n "$port" ] && break
  sleep 0.1
done
[ -n "$port" ] || { echo "page: FAIL — the server did not start"; cat "$TMP/server.out"; exit 1; }

"$chrome" --headless=new --disable-gpu --no-first-run --user-data-dir="$TMP/profile" \
  --virtual-time-budget=60000 --dump-dom "http://127.0.0.1:$port/check.html" > "$TMP/dom.html" 2> "$TMP/chrome.err"
verdict=$(sed -n '/<pre id="verdict">/,/<\/pre>/p' "$TMP/dom.html" | sed -e 's/<[^>]*>//g' -e 's/&quot;/"/g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&amp;/\&/g')
[ -n "$verdict" ] || { echo "page: FAIL — no verdict in the page"; tail -5 "$TMP/chrome.err"; exit 1; }
printf '%s\n' "$verdict" | grep '^FAIL'
last=$(printf '%s\n' "$verdict" | grep -v '^$' | tail -1)
echo "$last"
case "$last" in "page: all "*" PASS") exit 0 ;; *) exit 1 ;; esac
