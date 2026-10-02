#!/usr/bin/env bash
# tests/dazzle/build-cli.sh — build the Scaly dazzle DSSSL-transform CLI.
#
#   tests/dazzle/build-cli.sh [out-binary] [scalyc-binary]
#     out-binary    where to write the linked binary (default: /tmp/dazzle)
#     scalyc-binary compiler to use  (default: scalyc/build/scalyc)
#
# AOT-compiles the dazzle + opensp packages into archives and links
# packages/dazzle/0.1.0/dazzle_cli.scaly against them + the scaly runtime
# archive (same recipe as tests/sgml/build-onsgmls.sh). Then, e.g.:
#
#   tests/dazzle/build-cli.sh && /tmp/dazzle -t sgml -d map.dsl doc.xml

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${1:-/tmp/dazzle}"
BIN="${2:-$ROOT/scalyc/build/scalyc}"
# the tool beside the compiler: scaly for REPL/run/build/test, scalyc for the flags
SCALY=$("$ROOT/tools/scaly-of.sh" "$BIN")
cd "$ROOT"

# shellcheck disable=SC1091
source tools/llvm-env.sh >/dev/null 2>&1
# shellcheck disable=SC1091
. tests/platform.sh || exit 1
set -u

# What the suites invoke IS $OUT. Where the binary cannot be that file — a
# prebuilt one somewhere else, or the Windows box, where the CRT's TEXT-mode
# stdout would fail every byte comparison — $OUT becomes the two-line front
# end below over tests/win32/lf-wrapper.sh, and the binary lives beside it.
# `LFW_NAME="$0"` inside the front end matters: the wrapper reports argv[0] as
# the path IT was invoked as, and tests/dazzle/cli/run.sh normalises stderr by
# substituting exactly that path.
front_end() {
  printf '#!/bin/bash\nLFW_BIN=%s LFW_NAME="$0" exec %s "$@"\n' \
         "$1" "$ROOT/tests/win32/lf-wrapper.sh" > "$OUT" || exit 1
  chmod +x "$OUT"
}
# The Windows box (tests/platform.sh): the .exe lands beside the front end.
# ★NOT `$OUT.exe`: msys maps a path WITHOUT an extension onto an existing
# `.exe` of the same stem — for writing too — so `> "$OUT"` would overwrite
# the freshly linked binary with the two-line script (measured 2026-09-20 on
# the onsgmls twin: every corpus entry hung in a wrapper exec'ing itself).
EXE="$OUT"
[ "$SCALY_COFF" = 1 ] && EXE="$OUT-native.exe"

# ★A PREBUILT CLI (stage 7, rung 8). On the Windows runner nothing can compile
# — the objects are cross-emitted on the Linux leg — but the suites are worth
# running there, and a suite that had to be reimplemented for one platform
# would be a SECOND ORACLE, which is the one thing the corpus discipline in
# this tree does not allow. So the single place that produces the binary is
# also the place that can be told one already exists.
#
# What lands at $OUT is not the .exe but tests/win32/lf-wrapper.sh, because the
# suites compare bytes and Windows' CRT hands us a TEXT-mode stdout; the
# wrapper's header has the full reasoning, including why it must NOT touch a
# file the program writes itself. Every suite that calls this script therefore
# works unchanged on Windows.
if [ -n "${DAZZLE_PREBUILT:-}" ]; then
  if [ ! -x "$DAZZLE_PREBUILT" ]; then
    echo "dazzle-cli: FAIL (DAZZLE_PREBUILT=$DAZZLE_PREBUILT is not executable)"
    exit 1
  fi
  # A two-line front end rather than three environment variables the caller
  # would have to keep in step: what the suites invoke IS $OUT, so $OUT is the
  # place that knows which binary it stands for.
  front_end "$DAZZLE_PREBUILT"
  echo "dazzle-cli: using prebuilt $DAZZLE_PREBUILT (via lf-wrapper)"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- the one tool (ROADMAP-public.md, stage C) ------------------------------
# On a POSIX host the binary is `scaly build --release`: every package as
# bitcode out of the build cache, the whole program linked, optimised and
# emitted as one module in the compiler's own process -- what steps 1 to 3
# below did with llvm-link, sed, opt, llc and ar through tools/link-lto.sh
# (deleted 2026-10-01).
# Measured 2026-10-01 against that route: tests/dazzle/perf-survey.sh reads the
# same wall, cpu and peak RSS in every row, the binary is within 1 % of its
# size, and the build takes less than half the time. What stays of the old
# route is the ARITY GATE (tools/arity-audit.py over each package's IR), which
# the compiler does not diagnose yet.
# DAZZLE_NO_OPT=1 builds without the whole-program pass. SCALYC_NO_LTO=1 and the Windows box (no bitcode route there yet: its
# whole-program link is tools/win-lto.sh) take the archive steps below.
if [ "$SCALY_COFF" = 0 ] && [ "${SCALYC_NO_LTO:-0}" != "1" ]; then
  if command -v python3 >/dev/null 2>&1; then
    for PKG in dazzle opensp; do
      if ! "$BIN" -S --no-prelude -o "$TMP/$PKG.ll" "packages/$PKG/0.1.0/$PKG.scaly" > "$TMP/$PKG-emit.log" 2>&1; then
        echo "dazzle-cli: FAIL ($PKG emit)"; tail -8 "$TMP/$PKG-emit.log"; exit 1
      fi
      if ! python3 "$ROOT/tools/arity-audit.py" "$TMP/$PKG.ll" > "$TMP/$PKG-arity.log" 2>&1; then
        echo "dazzle-cli: FAIL ($PKG arity)"; cat "$TMP/$PKG-arity.log"; exit 1
      fi
    done
  fi
  RELEASE=--release
  # DAZZLE_NO_OPT=1: the acid loop asks a memory question, not a speed one --
  # the packages as cached objects, no whole-program pass
  [ -n "${DAZZLE_NO_OPT:-}" ] && RELEASE=
  if ! "$SCALY" build packages/dazzle/0.1.0/dazzle_cli.scaly $RELEASE -o "$EXE" > "$TMP/build.log" 2>&1; then
    echo "dazzle-cli: FAIL (build)"; tail -8 "$TMP/build.log"; exit 1
  fi
  echo "dazzle-cli: built $OUT (whole-program LTO)"
  exit 0
fi

# --- 1. dazzle + opensp packages -> archives ------------------------------
for PKG in dazzle opensp; do
  if ! "$BIN" -S --no-prelude -o "$TMP/$PKG.ll" "packages/$PKG/0.1.0/$PKG.scaly" > "$TMP/$PKG-emit.log" 2>&1; then
    echo "dazzle-cli: FAIL ($PKG emit)"; tail -8 "$TMP/$PKG-emit.log"; exit 1
  fi
  # Arity gate — see tools/arity-audit.py. A call site that passes fewer
  # arguments than its callee reads is a silent miscompile waiting for the
  # optimizer to reallocate the register; scalyc does not diagnose it yet, so
  # the IR is checked here, before opt can turn it into wrong output.
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 "$ROOT/tools/arity-audit.py" "$TMP/$PKG.ll" > "$TMP/$PKG-arity.log" 2>&1; then
      echo "dazzle-cli: FAIL ($PKG arity)"; cat "$TMP/$PKG-arity.log"; exit 1
    fi
  fi
  sed 's/^define linkonce_odr /define weak_odr /' "$TMP/$PKG.ll" > "$TMP/${PKG}_weak.ll"
  # The IR pipeline (`opt -O2`) before llc — same recipe as the runtime archive
  # below. Measured 2026-08-01: llc -O2 alone leaves 1.6-2.0x on the table (the
  # dazzledoc -t fot run goes 2.77 s -> 1.73 s) at byte-identical output. `opt`
  # is optional in tools/llvm-env.sh, so fall back to the bare weak IR.
  #
  # ★Turning this on first surfaced a REAL bug, not an opt bug: FotSink's tex
  # arm called TeXFOTBuilder.start_line_field() one argument short, so the
  # callee read whatever x1 happened to hold — the caller's own `nic`, by luck,
  # until opt reallocated the register. Only `-O0` hid it. If a suite ever
  # breaks under opt again, run the arity audit over the emitted .ll BEFORE
  # suspecting LLVM: a call site whose argument count disagrees with the
  # callee's definition is the signature of this class.
  OPTIN="$TMP/${PKG}_weak.ll"
  # DAZZLE_NO_OPT=1 skips the opt -O2 pipeline (llc still -O2): the acid loop
  # (packages/scalyc/CLAUDE.md, the opensp/dazzle acid tests) asks a memory
  # question of the binary, not a speed one, and opt was half of every build.
  if [ -n "${OPT:-}" ] && [ -z "${DAZZLE_NO_OPT:-}" ]; then
    if ! "$OPT" -O2 "$TMP/${PKG}_weak.ll" -o "$TMP/$PKG.bc" > "$TMP/$PKG-opt.log" 2>&1; then
      echo "dazzle-cli: FAIL ($PKG opt)"; tail -8 "$TMP/$PKG-opt.log"; exit 1
    fi
    OPTIN="$TMP/$PKG.bc"
  fi
  if ! "$LLC" -relocation-model=pic -O2 -filetype=obj "$OPTIN" -o "$TMP/$PKG.o" > "$TMP/$PKG-llc.log" 2>&1; then
    echo "dazzle-cli: FAIL ($PKG llc)"; tail -8 "$TMP/$PKG-llc.log"; exit 1
  fi
  ar rcs "$TMP/lib$PKG.a" "$TMP/$PKG.o"
done

# --- 2. runtime archive (build if a bare checkout lacks it) ---------------
# (the Windows box: libscaly.lib, built as CI's rung 3 builds it)
if [ "$SCALY_COFF" = 1 ]; then
  [ -f /tmp/libscaly.lib ] || tools/win-archive.sh "$BIN" > "$TMP/rt.log" 2>&1 || { echo "dazzle-cli: FAIL (runtime archive)"; tail -8 "$TMP/rt.log"; exit 1; }
elif [ ! -f /tmp/libscaly.a ]; then
  "$BIN" -S --no-prelude --no-tests -o /tmp/libscaly.ll packages/scaly/0.1.0/scaly.scaly > "$TMP/rt.log" 2>&1 || { echo "dazzle-cli: FAIL (runtime emit)"; tail -8 "$TMP/rt.log"; exit 1; }
  sed 's/^define linkonce_odr /define weak_odr /' /tmp/libscaly.ll > /tmp/libscaly_weak.ll
  "$OPT" -O2 /tmp/libscaly_weak.ll -o /tmp/libscaly_opt.bc >> "$TMP/rt.log" 2>&1 || { echo "dazzle-cli: FAIL (runtime opt)"; tail -8 "$TMP/rt.log"; exit 1; }
  "$LLC" -relocation-model=pic -O2 -filetype=obj /tmp/libscaly_opt.bc -o /tmp/libscaly.o >> "$TMP/rt.log" 2>&1 || { echo "dazzle-cli: FAIL (runtime llc)"; tail -8 "$TMP/rt.log"; exit 1; }
  tools/fcontext.sh /tmp/fcontext.o >> "$TMP/rt.log" 2>&1
  tools/eio.sh /tmp/eio.o >> "$TMP/rt.log" 2>&1
  tools/ctime.sh /tmp/ctime.o >> "$TMP/rt.log" 2>&1
  tools/panic.sh /tmp/panic.o >> "$TMP/rt.log" 2>&1
  ar rcs /tmp/libscaly.a /tmp/libscaly.o /tmp/fcontext.o /tmp/eio.o /tmp/ctime.o /tmp/panic.o
fi

# --- 3. link the program against the archives ----------------------------
# (the whole-program build is the tool's, above; this is the route of the
# Windows box and of SCALYC_NO_LTO=1)
if ! "$BIN" -o "$EXE" packages/dazzle/0.1.0/dazzle_cli.scaly "$TMP/libdazzle.a" "$TMP/libopensp.a" > "$TMP/link.log" 2>&1; then
  echo "dazzle-cli: FAIL (link)"; tail -8 "$TMP/link.log"; exit 1
fi
echo "dazzle-cli: built $EXE"
[ "$EXE" = "$OUT" ] || front_end "$EXE"
