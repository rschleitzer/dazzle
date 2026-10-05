#!/bin/bash
# A line-ending normalising front end for a Windows drop-in binary, so that the
# POSIX suites — the SAME harnesses and the SAME goldens — can judge it without
# a second copy of themselves. (Carried over from the Scaly compiler's tree,
# where these suites lived until 2026-10-05; tests/dazzle/build-cli.sh and
# tests/sgml/build-onsgmls.sh put it in front of the binary they build.)
#
#   LFW_BIN=<path to the .exe> lf-wrapper.sh <args…>
#
# ★ONE wrapper for both drop-ins on purpose. It began as `onsgmls-lf.sh`; when
# the dazzle CLI needed exactly the same two corrections it was generalised
# rather than copied, because both corrections are subtle enough that a second
# copy would be a second thing to get wrong (and the two harnesses normalise
# their diagnostics with the *same* assumption — see argv[0] below).
#
# WHY IT EXISTS. The goldens were taken on POSIX and are compared byte for byte.
# On Windows the CRT's stdout starts in TEXT mode, so every `\n` our runtime's
# `write` puts out leaves the process as `\r\n` — the ESIS stream, the flow
# object tree and the diagnostics alike. This puts the normalisation where a
# harness that knows nothing about Windows can use it.
#
# ★WHAT THIS IS NOT: a claim that the byte streams are identical. It is a
# COMPARISON-level decision, and the product question behind it is deliberately
# left open for stage 10 — *should* a drop-in emit LF on Windows? Generated code
# lands in customer repositories, where the answer matters and is not obviously
# "the same as POSIX". Written down here rather than settled in passing by a
# test harness. ★SETTLED 2026-10-03 by the author: a Scaly program's standard
# streams are BINARY on Windows (the runtime sets them before main), so a
# drop-in emits LF there as on POSIX, and a binary a current compiler built
# gives this wrapper no carriage return to remove.
#
# ★WHAT IT DELIBERATELY DOES NOT TOUCH: a file the program writes itself (an
# onsgmls `-t` RAST file, a dazzle `-o` output). Those go through OUR OWN
# `creat` in the Scaly runtime, which opens with an explicit _O_BINARY — so a
# carriage return in one would be a DEFECT, and normalising it here would hide
# exactly the regression the corpora exist to catch. stdout and stderr are
# different: they reach us through the CRT's fd 1 and 2, which are not ours.
#
# ★THE EXIT CODE IS THE POINT OF THE SHAPE BELOW. `prog | tr -d '\r'` reports
# TR's status, not the program's — a trap that has made every exit expectation
# of a suite pass vacuously before. Many of these assertions ARE exit
# codes, so there is no pipeline here at all: capture, then report, then exit
# with what the program said.
set -u

REAL=${LFW_BIN:?lf-wrapper.sh: set LFW_BIN to the drop-in binary}

# ★argv[0] is THE PATH THIS WRAPPER WAS INVOKED AS, not a fixed name, and the
# difference is not cosmetic: the harnesses do not agree on how they strip the
# program name from a diagnostic. Most use `sed 's/^[^:]*:/PROG:/'` (anything
# colon-free works), but tests/dazzle/cli/run.sh substitutes the LITERAL path
# it invoked — `sed "s|^$OUT|PROG|"`. A fixed `dazzle` satisfies the first kind
# and breaks the second; passing $0 satisfies both, because it makes the binary
# report exactly what a real binary sitting at that path would. Measured: with
# a fixed name that one suite failed on `notarc-spec` while four others passed.
# ★It also stays colon-free by construction — an msys path is `/d/a/…`, never
# `D:\…` — which is what the first kind of strip needs.
# ★It cannot simply be `$0`: when a front end execs THIS script, `exec -a` sets
# the argv[0] the kernel passes to the INTERPRETER, and a script's own `$0` is
# still its path — the same trap that made an earlier local test look green.
# So a caller that stands in for a binary passes the name it was invoked as;
# a caller that invokes this wrapper directly gets `$0`, which is the
# wrapper's own path and equally colon-free.
NAME=${LFW_NAME:-$0}

# ★FEW PROCESSES, on purpose (2026-09-20): this wrapper runs once per corpus
# entry, 380 times a corpus run, and on the Windows box a process start costs
# ~1 s while the antimalware service is busy
# — fourteen forks per entry made the corpus a 75-minute run. Everything
# below that bash can do with parameter expansion it does that way; what is
# left is the program, one cygpath and one sed per stream. Same bytes as the
# mktemp/printf/tr chain it replaces, measured against the goldens.
out=${TMPDIR:-/tmp}/lfw.$$.out; err=${TMPDIR:-/tmp}/lfw.$$.err
trap 'rm -f "$out" "$err"' EXIT

# ★argv[0] IS SET DELIBERATELY, and without it every diagnostic comparison
# fails. Both drop-ins take their program name straight from argv[0]
# (`let prog_name String(*argv)`, mirroring MessageReporter's programName_) and
# prefix each diagnostic with it; the harnesses strip that prefix again with
# `sed 's/^[^:]*://'` (onsgmls) and `sed 's/^[^:]*:/PROG:/'` (dazzle) under a
# comment stating that "program paths carry no colon". True on POSIX — and
# false the moment the path is `C:\…`, where the strip eats the drive letter
# and leaves the rest of the path in front of the message. So the binary is
# entered under a bare, colon-free argv[0].
# **An assumption a comment states as a fact is scoped to the platforms it was
# written on**, which is the same shape as `clock()`'s "1 000 000 on every
# target this builds for".
# ★INVOKED THROUGH THE FORWARD-SLASH SPELLING, and the reason is an encoder.
# Since `exec -a` does not take, argv[0] is whatever path we launch — and a
# BACKSLASH is not encoding-invariant: tests/dazzle/coding drives the same run
# through EUC-JP, where the diagnostics carrying the program name come out with
# each `\` as the two bytes a1 c0 (U+FF3C, fullwidth reverse solidus). The
# rewrite below then cannot match its own path, and the harness's `^[^:]*:`
# strip removes only the drive letter. `cygpath -m` gives `D:/a/…`, which is
# pure ASCII and therefore survives every encoder in that matrix byte for byte,
# so the rewrite works again and the colon disappears with the rest of the path.
# One cygpath for both spellings: the backslash form (-w) is what the CRT hands
# the program and what name_fix below rewrites; the mixed form (-m) is the same
# string with the separators flipped, so it is derived here rather than asked
# for a second time.
WINSELF=""
LAUNCH="$REAL"
if command -v cygpath > /dev/null 2>&1; then
  WINSELF=$(cygpath -w "$REAL" 2>/dev/null) || WINSELF=""
  [ -n "$WINSELF" ] && LAUNCH=${WINSELF//\\//}
fi
( exec -a "$NAME" "$LAUNCH" "$@" ) > "$out" 2> "$err"
rc=$?

# ★LC_ALL=C IS NOT DECORATION. `tr` in a UTF-8 locale rejects byte sequences
# that are not valid in it — BSD tr answers `tr: Illegal byte sequence`, writes
# NOTHING, and its complaint lands in the very stream being compared. An SGML
# corpus is the worst possible place for that: the encoding fixtures (Shift-JIS,
# EUC-JP, UCS-2, an out-of-range character reference) exist precisely to carry
# bytes that are not valid UTF-8. Measured before this line existed: 471 of 483
# models, all twelve failures "stderr differs", and every one of them an
# encoding fixture. In the C locale tr is a byte filter, which is what a
# line-ending normaliser has to be.
# (`tr -d '\r'` until 2026-09-20; the same global strip is now the first
# expression of the ONE sed per stream in fix_stream below — sed in the C
# locale is the same byte filter, and it saves a process per stream.)

# ★★★`exec -a` DOES NOT WORK for a native .exe under msys bash — measured, not
# suspected (2026-08-10). It is a shell builtin, and the msys layer rebuilds the
# command line on the way into CreateProcess, so the program still sees its real
# path. Proof came from a stream the first version did not touch: `--help`
# printed `Usage: D:\a\Scaly\Scaly\dazzle.exe [OPTION]` on STDOUT while every
# diagnostic on stderr looked correct, because only stderr was being repaired.
# ★So the repair is a REWRITE of both streams, not a hope about argv[0]. It
# satisfies all three harness conventions at once — tests/dazzle/cli/run.sh
# substitutes the literal invocation path ANYWHERE in a line
# (`sed "s|$OUT|PROG|"`), the other dazzle suites strip up to the first colon,
# and tests/sgml/run.sh does the same.
#
# ★★★AND IT REPLACES THE EXACT PATH, NOT A PATTERN THAT LOOKS LIKE ONE. The
# first version matched `[A-Za-z]:[^ ]*\.exe` — which also matches
# `s:<OSFILE>tiff.exe`, a NOTATION SYSTEM IDENTIFIER in tests/dazzle/prims'
# golden, so a generated-name test started reporting the wrapper's own path.
# Caught locally rather than in CI precisely because this wrapper is exercised
# on POSIX too. A normaliser that rewrites more than it was given is a corpus
# corruption with a friendly face: it edits the very bytes under test.
# So the string is asked for, not guessed — `cygpath -w` on our own binary —
# and on POSIX there is no cygpath, nothing is rewritten, and `exec -a` (which
# genuinely works there) has already made the program report $NAME.
# Escape a string for the LEFT side of a sed `s|…|…|` — the characters sed
# reads specially plus the `|` delimiter — with parameter expansion only (no
# printf, no sed, no tr: three processes per stream on the Windows box).
# `\` goes first, or the escapes just added would be escaped again.
sed_lhs() { # sed_lhs <var> <string>  (printf -v: a `$(…)` would fork too)
  local x=$2
  x=${x//\\/\\\\}
  x=${x//[/\\[}; x=${x//]/\\]}
  x=${x//./\\.}; x=${x//^/\\^}; x=${x//$/\\$}; x=${x//\*/\\*}
  x=${x//|/\\|}; x=${x//&/\\&}; x=${x//\//\\/}
  printf -v "$1" '%s' "$x"
}
fix_stream() {
  if [ -z "$WINSELF" ]; then LC_ALL=C sed -e 's/\r//g'; return; fi
  # Both spellings of the same path: the CRT hands the program the backslash
  # form, but anything that normalises a system identifier may print slashes.
  local b f
  sed_lhs b "$WINSELF"
  sed_lhs f "${WINSELF//\\//}"
  # ★AND ONE ANCHOR-BASED RULE, because an exact match is not always possible:
  # tests/dazzle/coding drives the same diagnostics through nine encoders, and a
  # BACKSLASH is not encoding-invariant — under EUC-JP each `\` of the Windows
  # path leaves as the two bytes a1 c0 (U+FF3C, fullwidth reverse solidus), so
  # the literal path above cannot match its own output. Launching through the
  # forward-slash spelling does NOT help: msys normalises the executable path
  # back to backslashes on the way into CreateProcess, measured twice, so
  # argv[0] is not ours to choose on this platform.
  # What IS invariant across every encoder in that matrix is the ASCII tail
  # `.exe:` — the letters and the colon pass through unchanged — so the program
  # name is cut at that anchor. Anchored at line start, and only where the
  # binary really is a .exe, i.e. never on POSIX.
  LC_ALL=C sed -e 's/\r//g' -e "s|$b|$NAME|g" -e "s|$f|$NAME|g" -e "s|^.*\.exe:|$NAME:|"
}

# ★STDERR FIRST. A native program's stderr is unbuffered and its stdout is
# flushed at exit, so in a `2>&1` capture the diagnostics precede the output;
# this wrapper replays two whole files and has to choose an order. With stdout
# first, a transform whose output ends WITHOUT a newline (`x`) glued itself
# onto the first stderr line — `xspecarena: documents released 2, held 0` —
# and tests/dazzle/specarena's `grep '^specarena: documents'` over the merged
# streams read nothing (measured 2026-09-20). Separate captures see no change.
fix_stream < "$err" >&2
fix_stream < "$out"

exit $rc
