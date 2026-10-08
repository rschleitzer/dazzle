#!/bin/bash
# tools/interface.sh -- the generated interfaces of the two packages.
#
#   tools/interface.sh [--check] [scalyc-binary]
#
# packages/<p>/<version>/interface/ is the package's module tree with every
# non-generic body replaced by `linked` and the facts a caller needs written
# out; the compiler writes it (`scalyc --emit-interface`), and a root that
# depends on the package reads the package through it. Without --check the
# interfaces are rewritten -- after any change to a package's sources, comments
# included; with it they are generated into a scratch directory and compared.
# opensp first: dazzle's facts are computed against opensp's interface.
set -u
cd "$(dirname "$0")/.."
CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
. tests/toolchain.sh "${1:-}" || exit 2
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
rc=0
for p in opensp dazzle; do
  v="$(tools/version.sh "$p")"; root="packages/$p/$v/$p.scaly"; out="packages/$p/$v/interface"
  if ! ( ulimit -s 65520 2>/dev/null; "$SCALYC" --emit-interface -o "$T/$p" "$root" ) > "$T/$p.out" 2>&1; then
    echo "interface: FAIL ($p)"; head -5 "$T/$p.out"; rc=1; continue
  fi
  if [ "$CHECK" = 1 ]; then
    if diff -r -q "$out" "$T/$p" > "$T/$p.diff" 2>&1; then
      echo "interface: $p current"
    else
      echo "interface: STALE $p -- run tools/interface.sh"; head -5 "$T/$p.diff"; rc=1
    fi
  else
    rm -rf "$out" && mv "$T/$p" "$out" && echo "interface: $p written"
  fi
done
exit $rc
