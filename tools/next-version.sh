#!/bin/bash
# tools/next-version.sh <package> <version> -- begin the next version of a
# package of this repository.
#
# A published version does not change (packages/<package>/published names
# them; `scaly publish` writes it). So the first change after a release
# begins a new version: the package's directory is renamed to the new number
# -- the published one lives on at its commit, which is where a build that
# declares it fetches it --, and what names the old number follows: the
# `package <package> <old>` declarations of the other packages and programs
# here, the version a program of the package says for itself, the README.
#
# The same renames a version that is NOT published yet -- 0.1.1 to 0.2.0, when
# `scaly publish --check` says the change takes the second number.
#
# A package here that declares this one and is itself published must get its
# next version first: its declaration cannot be touched. This says so.
set -eu
cd "$(dirname "$0")/.."
[ $# = 2 ] || { echo "usage: tools/next-version.sh <package> <version>" >&2; exit 2; }
p="$1"; new="$2"
old="$(tools/version.sh "$p")"
echo "$new" | grep -q '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' || { echo "next-version: $new is no version (three numbers)" >&2; exit 2; }
[ "$(printf '%s\n%s\n' "$old" "$new" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)" = "$new" ] && [ "$old" != "$new" ] \
  || { echo "next-version: $p is at $old, $new is not higher" >&2; exit 1; }
[ -z "$(git status --porcelain -- "packages/$p")" ] || { echo "next-version: packages/$p has uncommitted changes -- commit them first" >&2; exit 1; }
published() { [ -f "packages/$1/published" ] && grep -q "^$2 " "packages/$1/published"; }

olde="$(echo "$old" | sed 's/\./\\./g')"
# who declares the old version, outside the package's own directory
users="$(git grep -l "^package $p $olde\$" -- '*.scaly' ":!packages/$p/$old" ':!upstream' || true)"
for f in $users; do
  case "$f" in
    packages/*/interface/*) ;;
    packages/*/*/*)
      up="$(echo "$f" | cut -d/ -f2)"; uv="$(echo "$f" | cut -d/ -f3)"
      if published "$up" "$uv"; then
        echo "next-version: $up $uv is published and declares $p $old ($f)." >&2
        echo "  Begin its next version first: tools/next-version.sh $up <version>" >&2
        exit 1
      fi ;;
  esac
done

git mv "packages/$p/$old" "packages/$p/$new"
n=0
for f in $(git grep -l "^package $p $olde\$" -- '*.scaly' ':!upstream' || true); do
  sed -i.bak "s/^package $p $olde\$/package $p $new/" "$f" && rm -f "$f.bak"; n=$((n+1))
done
for f in "packages/$p/$new/programs"/*.scaly; do
  [ -f "$f" ] || continue
  sed -i.bak "s/^    StringC(\"$olde\")\$/    StringC(\"$new\")/" "$f" && rm -f "$f.bak"
done
sed -i.bak "s/\\([ /]\\)$p $olde\\([ ]\\)/\\1$p $new\\2/g" README.md && rm -f README.md.bak
echo "next-version: $p $old -> $new (packages/$p/$new; $n files declare it)"
if published "$p" "$old"; then
  echo "  $old is published: it stays what it was, at its commit."
else
  echo "  $old was not published: this is a renumbering."
fi
echo "  Next: tools/interface.sh (the generated interfaces name versions), tests/run.sh, commit."
