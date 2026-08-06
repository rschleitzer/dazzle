#!/usr/bin/env bash
# tests/dazzle/framevol/run.sh — build a frame-VOLUME probe build of the dazzle
# CLI and run something with it.
#
#   tests/dazzle/framevol/run.sh <out-binary> [scalyc-binary]
#     … then run <out-binary> with DZ_FRAME_VOL=1 (see README.md).
#
# Same shape as tests/dazzle/frameprobe/run.sh and for the same reason: the
# probe is not part of the shipped engine, so the instrumented engine is
# assembled out of the tree instead of into it —
#
#   1. a git worktree at HEAD (the tree you are working in stays untouched),
#   2. FrameVol.scaly copied into the dazzle package + declared as a module,
#   3. four hooks inserted by exact string replacement — VM.push_frame and
#      VM.pop_frame (the frame boundaries) and Interpreter.set_eval_region (the
#      bracket switch), plus the two `use` lines. A replacement whose anchor is
#      gone fails LOUDLY: that means the engine moved and the hook needs
#      re-aiming, not that the probe is broken,
#   4. the ordinary whole-program LTO link of build-cli.sh — unlike frameprobe
#      this probe needs no C shim, so nothing in the build scripts is patched.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-/tmp/dazzle-framevol}"
BIN="${2:-$ROOT/scalyc/build/scalyc}"
WT="$(mktemp -d)/wt"

cd "$ROOT"
git worktree add --detach "$WT" HEAD > /dev/null 2>&1 || { echo "framevol: FAIL (worktree)"; exit 1; }
trap 'cd "$ROOT"; git worktree remove --force "$WT" >/dev/null 2>&1; rm -rf "$(dirname "$WT")"' EXIT

cp "$HERE/FrameVol.scaly" "$WT/packages/dazzle/0.1.0/dazzle/FrameVol.scaly"

python3 - "$WT" <<'PY' || { echo "framevol: FAIL (hooks — an anchor moved, re-aim it)"; exit 1; }
import sys
wt = sys.argv[1]
def patch(path, pairs):
    p = wt + path
    s = open(p).read()
    for old, new in pairs:
        if old not in s:
            raise SystemExit("anchor not found in %s:\n%s" % (path, old))
        s = s.replace(old, new, 1)
    open(p, 'w').write(s)

patch('/packages/dazzle/0.1.0/dazzle.scaly', [(
    "    ; NamedTable<T> (generic/NamedTable.h) — the hash-probed name index behind",
    "    ; the DZ_FRAME_VOL frame-volume measurement hook (tests/dazzle/framevol).\n"
    "    ; Declared FIRST: VM and Interpreter call into it, and it depends on\n"
    "    ; nothing but Page.\n"
    "    module FrameVol\n"
    "    ; NamedTable<T> (generic/NamedTable.h) — the hash-probed name index behind")])

patch('/packages/dazzle/0.1.0/dazzle/VM.scaly', [
    ("use dazzle.ELObj.GlyphSubstTableRec",
     "use dazzle.ELObj.GlyphSubstTableRec\nuse dazzle.FrameVol.FrameVol"),
    # push_frame, after csp was incremented: the new frame's index is csp-1
    ("        set e.continuation: null\n        set this.csp: this.csp + 1\n    }",
     "        set e.continuation: null\n        set this.csp: this.csp + 1\n"
     "        FrameVol.push(this.csp)\n    }"),
    # pop_frame, after csp was decremented: the leaving frame's index IS csp
    ("        set this.closure_loc: e.closure_loc\n        e.next",
     "        set this.closure_loc: e.closure_loc\n"
     "        FrameVol.pop(this.csp)\n        e.next")])

patch('/packages/dazzle/0.1.0/dazzle/Interpreter.scaly', [
    ("use dazzle.NameTable.NameTable",
     "use dazzle.FrameVol.FrameVol\nuse dazzle.NameTable.NameTable"),
    ("    procedure set_eval_region(this: pointer[Interpreter], p: pointer[Page])\n        set eval_region: p",
     "    procedure set_eval_region(this: pointer[Interpreter], p: pointer[Page])\n    {\n"
     "        ; DZ_FRAME_VOL: the region clock changes with the bracket, so the\n"
     "        ; parent's clock has to be stacked and resumed.\n"
     "        FrameVol.region(p)\n"
     "        set eval_region: p\n    }")])
PY

TMP="$(mktemp -d)"
cd "$WT"
if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$TMP/build.log" 2>&1; then
  echo "framevol: FAIL (build)"; tail -20 "$TMP/build.log"; rm -rf "$TMP"; exit 1
fi
rm -rf "$TMP"
echo "framevol: built $OUT (run it with DZ_FRAME_VOL=1; see $HERE/README.md)"
