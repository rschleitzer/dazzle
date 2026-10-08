#!/usr/bin/env bash
# tools/release.sh — the programs of this repository as one archive for the
# system it runs on: dazzle and onsgmls, each built with a profile.
#
#   tools/release.sh [outdir]          # default dist/
#
# What it needs:
#   scaly              the tool, on the PATH or named by $SCALY (https://scaly.io)
#   llvm-profdata      of the LLVM that scaly was built with (21), on the PATH,
#                      named by $PROFDATA, or under Homebrew's llvm@21; and that
#                      LLVM's clang, which links the instrumented program
#   git                to fetch the training material
#
# Two things a build machine may say:
#   RELEASE_SYSTEM     the system's name in the archive (windows-arm64), where
#                      the shell cannot tell: a bash emulated on an arm64
#                      Windows reports x86_64
#   RELEASE_SKIP       suites of step 5 this machine cannot run, by name
#                      ("pdf rtf") -- said in the output, never silently
#
# What it does:
#   1. stamps the version: `dazzle -v` of a released program says
#      "<version> <day> <commit>" (one line of programs/dazzle.scaly, put back at
#      the end)
#   2. builds dazzle and onsgmls instrumented (`scaly build --pgo-train`)
#   3. trains it on what the Scaly repository itself runs: ./mkp (the parser
#      and syntax generators, the literate tests) and the specification as HTML
#      and as PDF. Measured 2026-10-07: that profile takes 13 % off a
#      production code generator and 16 % off another -- more than a profile
#      made from one of those generators took off the other.
#      $SCALY_TRAIN names a checkout of github.com/rschleitzer/Scaly to train
#      on (it is written into: use a clone made for this); unset, one is
#      fetched.
#      onsgmls is trained on the documents those runs read: the grammar, the
#      literate tests and the specification, each parsed to its ESIS and once
#      more with -s, the parse alone.
#   4. builds both with their profiles
#   5. checks the result: the profiled dazzle must regenerate the training
#      checkout's generated files byte for byte (they are checked in there),
#      and pass every dazzle suite of this repository; the profiled onsgmls
#      must write the ESIS the instrumented one wrote, byte for byte
#   6. packs dazzle, onsgmls and the licence, with a checksum beside the archive
#
# The archive is named dazzle-<day>-<commit>-<system>: a version of the
# packages is published with a release and worked on in between, so the day
# and the commit are what tells two archives apart. The version is the one
# tools/version.sh names.
set -eu
cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="${1:-dist}"
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac

SCALY="${SCALY:-$(command -v scaly || true)}"
[ -n "$SCALY" ] && [ -x "$SCALY" ] || { echo "release: FAIL — no scaly on the PATH (or \$SCALY)"; exit 1; }

PROFDATA="${PROFDATA:-}"
if [ -z "$PROFDATA" ]; then
  # the one of LLVM 21 first: a plain `llvm-profdata` on the PATH may be
  # another LLVM's, and that one refuses the raw profile by its version
  for c in llvm-profdata-21 /opt/homebrew/opt/llvm@21/bin/llvm-profdata /usr/local/opt/llvm@21/bin/llvm-profdata llvm-profdata; do
    if command -v "$c" > /dev/null 2>&1; then PROFDATA="$c"; break; fi
  done
fi
[ -n "$PROFDATA" ] || { echo "release: FAIL — no llvm-profdata (LLVM 21) on the PATH (or \$PROFDATA)"; exit 1; }

EXE=""
case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux)  os=linux ;;
  MINGW*|MSYS*|CYGWIN*) os=windows; EXE=.exe ;;
  *) echo "release: FAIL — unknown system $(uname -s)"; exit 1 ;;
esac
case "$(uname -m)" in
  arm64|aarch64) arch=arm64 ;;
  x86_64|amd64)  arch=x86_64 ;;
  *) echo "release: FAIL — unknown machine $(uname -m)"; exit 1 ;;
esac
# an x64 shell on an arm64 Windows reports the shell's machine, not the system's
if [ "$os" = windows ] && [ "${PROCESSOR_ARCHITECTURE:-}" = ARM64 ]; then arch=arm64; fi
[ "$os" = linux ] && [ "$arch" = arm64 ] && arch=aarch64
SYSTEM="${RELEASE_SYSTEM:-$os-$arch}"

DAY="$(git log -1 --format=%cd --date=format:%Y-%m-%d)"
COMMIT="$(git rev-parse --short=7 HEAD)"
STAMP="$DAY-$COMMIT"
NAME="dazzle-$STAMP-$SYSTEM"

W="$(mktemp -d)"
V="$(tools/version.sh dazzle)"
PROGRAM="packages/dazzle/$V/programs/dazzle.scaly"
cp "$PROGRAM" "$W/dazzle.scaly.kept"
trap 'cp "$W/dazzle.scaly.kept" "$ROOT/$PROGRAM"; rm -rf "$W"' EXIT

echo "release: $NAME"

# 1. the stamp
grep -q "^    StringC(\"$V\")\$" "$PROGRAM" || { echo "release: FAIL — the version line of $PROGRAM is not where it was"; exit 1; }
sed "s|^    StringC(\"$V\")\$|    StringC(\"$V $DAY $COMMIT\")|" "$W/dazzle.scaly.kept" > "$PROGRAM"

export SCALY_CACHE="$W/cache"

# 2. instrumented
echo "release: dazzle, instrumented"
"$SCALY" build "$PROGRAM" --pgo-train -o "$W/dazzle-train$EXE" > "$W/train-build.log" 2>&1 \
  || { tail -20 "$W/train-build.log"; echo "release: FAIL — the instrumented build"; exit 1; }

echo "release: onsgmls, instrumented"
ONSGMLS="packages/opensp/$(tools/version.sh opensp)/programs/onsgmls.scaly"
"$SCALY" build "$ONSGMLS" --pgo-train -o "$W/onsgmls-train$EXE" > "$W/onsgmls-train-build.log" 2>&1 \
  || { tail -20 "$W/onsgmls-train-build.log"; echo "release: FAIL — the instrumented build of onsgmls"; exit 1; }

# 3. training
TRAIN="${SCALY_TRAIN:-}"
if [ -z "$TRAIN" ]; then
  TRAIN="$W/Scaly"
  echo "release: fetching the training material"
  # as it is in the repository: a Git for Windows that turns line ends on
  # checkout would hand the check below files nobody generated
  git -c core.autocrlf=false clone -q --depth 1 https://github.com/rschleitzer/Scaly "$TRAIN"
fi
[ -x "$TRAIN/mkp" ] || { echo "release: FAIL — no mkp in $TRAIN"; exit 1; }
# The runs write line feeds on every system (SP_LINE_TERM, the reference's
# own switch): the files they regenerate are checked in that way, and step 5
# compares them byte for byte. On Windows the engine would write CR LF.
export SP_LINE_TERM=lf
train() { # the three runs with the engine $1
  ( cd "$TRAIN" && DAZZLE="$1" DAZZLE_REPO="$W/none" SCALY_HOME="$TRAIN" ./mkp ) > "$W/mkp.log" 2>&1 \
    || { tail -20 "$W/mkp.log"; return 1; }
  ( cd "$TRAIN/docs" && DAZZLE="$1" ./html.sh && DAZZLE="$1" ./pdf.sh ) > "$W/docs.log" 2>&1 \
    || { tail -20 "$W/docs.log"; return 1; }
}
echo "release: training"
mkdir -p "$W/prof"
LLVM_PROFILE_FILE="$W/prof/train-%p.profraw" train "$W/dazzle-train$EXE" \
  || { echo "release: FAIL — a training run"; exit 1; }
ls "$W/prof"/*.profraw > /dev/null 2>&1 || { echo "release: FAIL — the training runs wrote no profile"; exit 1; }
"$PROFDATA" merge -o "$W/dazzle.profdata" "$W/prof"/*.profraw

# onsgmls: the documents the runs above read, each to its ESIS (kept, for the
# check in step 5). The specification is the large one -- a DocBook book with
# its DTD and every chapter an entity.
parse_all() { # the parses with the program $1, their output into the directory $2
  mkdir -p "$2"
  ( cd "$TRAIN" && for d in scaly.sgm tests/expressions.sgm tests/definitions.sgm tests/choose.sgm tests/controlflow.sgm; do
      "$1" "$d" > "$2/$(basename "$d").esis" 2> "$2/$(basename "$d").err" || exit 1
      "$1" -s "$d" > /dev/null 2>&1 || exit 1
    done ) || return 1
  ( cd "$TRAIN/docs" && SP_ENCODING=utf-8 "$1" scaly-spec.xml > "$2/scaly-spec.esis" 2> "$2/scaly-spec.err" \
      && SP_ENCODING=utf-8 "$1" -s scaly-spec.xml > /dev/null 2>&1 ) || return 1
}
mkdir -p "$W/prof-onsgmls"
LLVM_PROFILE_FILE="$W/prof-onsgmls/train-%p.profraw" parse_all "$W/onsgmls-train$EXE" "$W/esis-train" \
  || { echo "release: FAIL — a training parse of onsgmls"; exit 1; }
ls "$W/prof-onsgmls"/*.profraw > /dev/null 2>&1 || { echo "release: FAIL — the training parses wrote no profile"; exit 1; }
"$PROFDATA" merge -o "$W/onsgmls.profdata" "$W/prof-onsgmls"/*.profraw

# 4. the programs
echo "release: dazzle and onsgmls with their profiles"
"$SCALY" build "$PROGRAM" --pgo "$W/dazzle.profdata" -o "$W/dazzle$EXE" > "$W/pgo-build.log" 2>&1 \
  || { tail -20 "$W/pgo-build.log"; echo "release: FAIL — the build with the profile"; exit 1; }
stale=$(grep -c 'profile data may be out of date\|function control flow change detected' "$W/pgo-build.log" || true)
[ "$stale" = 0 ] || { echo "release: FAIL — $stale warnings of a profile that does not fit the program"; exit 1; }
"$SCALY" build "$ONSGMLS" --pgo "$W/onsgmls.profdata" -o "$W/onsgmls$EXE" > "$W/onsgmls-build.log" 2>&1 \
  || { tail -20 "$W/onsgmls-build.log"; echo "release: FAIL — onsgmls with the profile"; exit 1; }
stale=$(grep -c 'profile data may be out of date\|function control flow change detected' "$W/onsgmls-build.log" || true)
[ "$stale" = 0 ] || { echo "release: FAIL — $stale warnings of a profile that does not fit onsgmls"; exit 1; }

# 5. the checks
said="$("$W/dazzle$EXE" -v < /dev/null 2>&1 | head -1 | sed 's/.*:I: //')"
[ "$said" = "\"dazzle\" version \"$V $DAY $COMMIT\"" ] || { echo "release: FAIL — the program says: $said"; exit 1; }
echo "release: checking — the training checkout regenerated"
git -C "$TRAIN" checkout -q -- . 2>/dev/null || true
train "$W/dazzle$EXE" || { echo "release: FAIL — the profiled program on the training runs"; exit 1; }
changed="$(git -C "$TRAIN" status --porcelain --untracked-files=no | grep -v ' docs/' || true)"
[ -z "$changed" ] || { echo "$changed" | head -10; echo "release: FAIL — the profiled program generates other files than are checked in"; exit 1; }
echo "release: checking — onsgmls parses as it did in training"
parse_all "$W/onsgmls$EXE" "$W/esis-check" || { echo "release: FAIL — a parse of the profiled onsgmls"; exit 1; }
for e in "$W/esis-train"/*.esis; do
  cmp -s "$e" "$W/esis-check/$(basename "$e")" || { echo "release: FAIL — the profiled onsgmls writes another ESIS for $(basename "$e" .esis)"; exit 1; }
done
unset SP_LINE_TERM
echo "release: checking — the suites"
failed=""
for d in cli coding engine flowobj fot framemark grove html mif pdf prims rtf specarena tex; do
  case " ${RELEASE_SKIP:-} " in *" $d "*) echo "  dazzle-$d: SKIPPED (RELEASE_SKIP)"; continue ;; esac
  if DAZZLE_PREBUILT="$W/dazzle$EXE" "tests/dazzle/$d/run.sh" > "$W/suite-$d.log" 2>&1; then
    echo "  $(tail -1 "$W/suite-$d.log" | cut -c1-100)"
  else
    echo "  dazzle-$d: FAIL"; tail -8 "$W/suite-$d.log" | sed 's/^/    /'; failed="$failed $d"
  fi
done
[ -z "$failed" ] || { echo "release: FAIL — suites:$failed"; exit 1; }

# 6. the archive
mkdir -p "$OUT" "$W/$NAME"
cp "$W/dazzle$EXE" "$W/onsgmls$EXE" LICENSE "$W/$NAME/"
# the pdf package the programs were built with: a checkout linked in as
# packages/pdf (it must be committed), else what scaly fetched
PDFV="$(sed -n 's/^package pdf \([0-9.]*\) .*/\1/p' "packages/dazzle/$V/dazzle.scaly" | head -1)"
[ -n "$PDFV" ] || { echo "release: FAIL — the dazzle package does not declare the pdf package"; exit 1; }
if [ -d "packages/pdf/$PDFV" ]; then
  git -C "packages/pdf/$PDFV" diff --quiet HEAD -- . 2>/dev/null \
    || { echo "release: FAIL — the pdf checkout behind packages/pdf has uncommitted changes"; exit 1; }
  PDF="$(git -C "packages/pdf/$PDFV" rev-parse HEAD 2>/dev/null | cut -c1-7)"
else
  PDF="$(sed -n 's/^commit //p' "${SCALY_PACKAGES:-${HOME:-$USERPROFILE}/.scaly/packages}/github.com/rschleitzer/pdf/packages/pdf/$PDFV.fetched" 2>/dev/null | cut -c1-7)"
fi
[ -n "$PDF" ] || { echo "release: FAIL — cannot tell which commit of the pdf package was built in"; exit 1; }
printf "dazzle $V %s %s for %s\npdf $PDFV %s\nhttps://github.com/rschleitzer/dazzle\n" "$DAY" "$COMMIT" "$SYSTEM" "$PDF" > "$W/$NAME/VERSION"
if [ "$os" = windows ]; then
  ARCHIVE="$NAME.zip"
  ( cd "$W" && "$(cygpath -u "${SYSTEMROOT:-C:\\Windows}")/System32/tar.exe" -a -c -f "$(cygpath -w "$OUT/$ARCHIVE")" "$NAME" )
else
  ARCHIVE="$NAME.tar.gz"
  tar -czf "$OUT/$ARCHIVE" -C "$W" "$NAME"
fi
( cd "$OUT" && { command -v sha256sum > /dev/null 2>&1 && sha256sum "$ARCHIVE" || shasum -a 256 "$ARCHIVE"; } > "$ARCHIVE.sha256" )
echo "release: OK -> $OUT/$ARCHIVE ($(du -h "$OUT/$ARCHIVE" | cut -f1))"
