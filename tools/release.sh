#!/usr/bin/env bash
# tools/release.sh — the programs of this repository as one archive for the
# system it runs on: dazzle built with a profile, onsgmls beside it.
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
#      "0.1.0 <day> <commit>" (one line of programs/dazzle.scaly, put back at
#      the end)
#   2. builds dazzle instrumented (`scaly build --pgo-train`)
#   3. trains it on what the Scaly repository itself runs: ./mkp (the parser
#      and syntax generators, the literate tests) and the specification as HTML
#      and as PDF. Measured 2026-10-07: that profile takes 13 % off a
#      production code generator and 16 % off another -- more than a profile
#      made from one of those generators took off the other.
#      $SCALY_TRAIN names a checkout of github.com/rschleitzer/Scaly to train
#      on (it is written into: use a clone made for this); unset, one is
#      fetched.
#   4. builds dazzle with the profile, onsgmls `--release`
#   5. checks the result: the profiled dazzle must regenerate the training
#      checkout's generated files byte for byte (they are checked in there),
#      and pass every dazzle suite of this repository
#   6. packs dazzle, onsgmls and the licence, with a checksum beside the archive
#
# The archive is named dazzle-<day>-<commit>-<system>: this repository's
# packages stay at 0.1.0 while they change, so the day and the commit are what
# tells two archives apart.
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
PROGRAM=packages/dazzle/0.1.0/programs/dazzle.scaly
cp "$PROGRAM" "$W/dazzle.scaly.kept"
trap 'cp "$W/dazzle.scaly.kept" "$ROOT/$PROGRAM"; rm -rf "$W"' EXIT

echo "release: $NAME"

# 1. the stamp
grep -q '^    StringC("0.1.0")$' "$PROGRAM" || { echo "release: FAIL — the version line of $PROGRAM is not where it was"; exit 1; }
sed "s|^    StringC(\"0.1.0\")\$|    StringC(\"0.1.0 $DAY $COMMIT\")|" "$W/dazzle.scaly.kept" > "$PROGRAM"

export SCALY_CACHE="$W/cache"

# 2. instrumented
echo "release: dazzle, instrumented"
"$SCALY" build "$PROGRAM" --pgo-train -o "$W/dazzle-train$EXE" > "$W/train-build.log" 2>&1 \
  || { tail -20 "$W/train-build.log"; echo "release: FAIL — the instrumented build"; exit 1; }

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

# 4. the programs
echo "release: dazzle with the profile, onsgmls"
"$SCALY" build "$PROGRAM" --pgo "$W/dazzle.profdata" -o "$W/dazzle$EXE" > "$W/pgo-build.log" 2>&1 \
  || { tail -20 "$W/pgo-build.log"; echo "release: FAIL — the build with the profile"; exit 1; }
stale=$(grep -c 'profile data may be out of date\|function control flow change detected' "$W/pgo-build.log" || true)
[ "$stale" = 0 ] || { echo "release: FAIL — $stale warnings of a profile that does not fit the program"; exit 1; }
"$SCALY" build packages/opensp/0.1.0/programs/onsgmls.scaly --release -o "$W/onsgmls$EXE" > "$W/onsgmls-build.log" 2>&1 \
  || { tail -20 "$W/onsgmls-build.log"; echo "release: FAIL — onsgmls"; exit 1; }

# 5. the checks
said="$("$W/dazzle$EXE" -v < /dev/null 2>&1 | head -1 | sed 's/.*:I: //')"
[ "$said" = "\"dazzle\" version \"0.1.0 $DAY $COMMIT\"" ] || { echo "release: FAIL — the program says: $said"; exit 1; }
echo "release: checking — the training checkout regenerated"
git -C "$TRAIN" checkout -q -- . 2>/dev/null || true
train "$W/dazzle$EXE" || { echo "release: FAIL — the profiled program on the training runs"; exit 1; }
changed="$(git -C "$TRAIN" status --porcelain --untracked-files=no | grep -v ' docs/' || true)"
[ -z "$changed" ] || { echo "$changed" | head -10; echo "release: FAIL — the profiled program generates other files than are checked in"; exit 1; }
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
printf 'dazzle 0.1.0 %s %s for %s\nhttps://github.com/rschleitzer/dazzle\n' "$DAY" "$COMMIT" "$SYSTEM" > "$W/$NAME/VERSION"
if [ "$os" = windows ]; then
  ARCHIVE="$NAME.zip"
  ( cd "$W" && "$(cygpath -u "${SYSTEMROOT:-C:\\Windows}")/System32/tar.exe" -a -c -f "$(cygpath -w "$OUT/$ARCHIVE")" "$NAME" )
else
  ARCHIVE="$NAME.tar.gz"
  tar -czf "$OUT/$ARCHIVE" -C "$W" "$NAME"
fi
( cd "$OUT" && { command -v sha256sum > /dev/null 2>&1 && sha256sum "$ARCHIVE" || shasum -a 256 "$ARCHIVE"; } > "$ARCHIVE.sha256" )
echo "release: OK -> $OUT/$ARCHIVE ($(du -h "$OUT/$ARCHIVE" | cut -f1))"
