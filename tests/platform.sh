#!/bin/bash
# tests/platform.sh — sourced by the suite runners; the ONE place that tells a
# Windows shell (Git Bash, COFF) from the POSIX hosts. Everything a runner does
# differently there comes from here, so a runner reads the same on both and the
# difference is auditable in one file.
#
# (Carried over from the Scaly compiler's tree, where these suites lived until
# 2026-10-05, and cut down to what they use: the compiler project's own
# defaults — its bootstrap stage, its developer-prompt environment, its LLVM
# paths — stayed there. The compiler and the tool come from tests/toolchain.sh.)
#
#   SCALY_COFF           1 on a Windows shell, 0 elsewhere
#   SCALY_EXE            ".exe" there, empty elsewhere — appended to every
#                        binary a runner builds and executes
#   scaly_jit_available  true on every host: `scaly test` runs a package's
#                        tests through the in-process JIT, on Windows too
#                        since 2026-10-03. Kept as a question so that a host
#                        without a JIT has one place to say so.
#   scaly_lf             strips carriage returns on a Windows shell, identity
#                        on POSIX (account below)
#
# Git Bash mounts $TMP as /tmp, so a /tmp path is one string on both.

SCALY_COFF=0
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) SCALY_COFF=1 ;; esac
SCALY_EXE=
if [ "$SCALY_COFF" = 1 ]; then
  SCALY_EXE=.exe
  # ★`TMP` is not a free name here: Windows
  # EXPORTS it, and a dozen runners write `TMP="$(mktemp -d)"` for their own
  # scratch — an assignment to an exported name stays exported, so every
  # compiler they then start read ITS scratch dir off the runner's, and the
  # link died on `<runner scratch>/libscaly.lib` (measured 2026-09-20, every
  # suite that links). Dropping the export attribute once, here, keeps those
  # assignments shell-local; the compiler and clang fall back to `TEMP`, the
  # same directory, which nothing in the tree assigns.
  export -n TMP
  # ★Windows' installer detection judges an executable by its NAME: one that
  # contains `setup`, `install`, `update` or `patch` and carries no manifest
  # asks for elevation, and a start from bash is then `Permission denied`,
  # rc 126. RunAsInvoker tells the loader to start what it is given with the
  # caller's rights.
  export __COMPAT_LAYER=RunAsInvoker
fi

scaly_jit_available() { true; }

# stdout of a program on Windows arrived with CRLF until 2026-10-03: the
# CRT's fd 1 starts in TEXT mode and turned every `\n` our runtime writes into
# `\r\n`. A Scaly program's standard streams are BINARY there since (set before
# main by the runtime), so for a program a current compiler built this filter
# removes nothing; it stays for a binary an older compiler built
# (tests/win32/lf-wrapper.sh has the account). In the C locale so that it is a
# byte filter. Never in a pipeline with the program itself — `prog | scaly_lf`
# reports the FILTER's exit code — always on a captured file. Identity on POSIX.
scaly_lf() { if [ "$SCALY_COFF" = 1 ]; then LC_ALL=C tr -d '\r'; else cat; fi; }
