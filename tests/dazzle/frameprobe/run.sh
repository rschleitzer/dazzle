#!/usr/bin/env bash
# tests/dazzle/frameprobe/run.sh — build a frame-lifetime PROBE build of the
# dazzle CLI and run something with it.
#
#   tests/dazzle/frameprobe/run.sh <out-binary> [scalyc-binary]
#     … then run <out-binary> with DZ_FRAME_PROBE=1 (see README.md).
#
# The probe is NOT part of the shipped engine: it needs a SIGSEGV/SIGBUS
# handler shim, and a new shim in the dazzle package would be unresolvable on
# the `--jit` leg of tests/dazzle/run.sh (the compiler process supplies the
# runtime's shims, not the package's). So this script assembles the
# instrumented engine out of the tree instead:
#
#   1. a git worktree at HEAD (the tree you are working in stays untouched),
#   2. FrameProbe.scaly copied into the dazzle package + declared as a module,
#   3. four hooks inserted by exact string replacement — Primitive.dispatch
#      (host swap for the probed primitives), VM.pop_frame (the frame clock and
#      the arming point), VM.eval (arm what an error unwind abandons), VM.make
#      (a probe id per VM) and Interpreter.set_eval_region (the generation
#      counter). A replacement whose anchor is gone fails LOUDLY — that means
#      the engine moved and the hook needs re-aiming, not that the probe is
#      broken,
#   4. the whole-program LTO link of build-cli.sh, with frameprobe.o appended
#      to the final link line (patched in the worktree too, so nothing in the
#      shipped build scripts knows about the probe).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-/tmp/dazzle-frameprobe}"
BIN="${2:-$ROOT/scalyc/build/scalyc}"
WT="$(mktemp -d)/wt"

cd "$ROOT"
git worktree add --detach "$WT" HEAD > /dev/null 2>&1 || { echo "frameprobe: FAIL (worktree)"; exit 1; }
trap 'cd "$ROOT"; git worktree remove --force "$WT" >/dev/null 2>&1; rm -rf "$(dirname "$WT")"' EXIT

cp "$HERE/FrameProbe.scaly" "$WT/packages/dazzle/0.1.0/dazzle/FrameProbe.scaly"

python3 - "$WT" <<'PY' || { echo "frameprobe: FAIL (hooks — an anchor moved, re-aim it)"; exit 1; }
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
    "    ; the DZ_FRAME_PROBE frame-lifetime measurement hook (tests/dazzle/frameprobe).\n"
    "    ; Declared FIRST: VM, Primitive and Interpreter call into it, and it depends\n"
    "    ; on nothing but Page.\n"
    "    module FrameProbe\n"
    "    ; NamedTable<T> (generic/NamedTable.h) — the hash-probed name index behind")])

patch('/packages/dazzle/0.1.0/dazzle/VM.scaly', [
    ("use dazzle.ELObj.GlyphSubstTableRec",
     "use dazzle.ELObj.GlyphSubstTableRec\nuse dazzle.FrameProbe.FrameProbe"),
    ("    current_language: pointer[ELObj]\n)",
     "    current_language: pointer[ELObj]\n    probe_id: i64\n)"),
    ("        set vm.current_language: null\n        vm\n    }",
     "        set vm.current_language: null\n        set vm.probe_id: FrameProbe.next_vm_id()\n        vm\n    }\n\n"
     "    function get_probe_id(this: VM) returns i64\n        probe_id"),
    ("        set this.closure_loc: e.closure_loc\n        e.next",
     "        set this.closure_loc: e.closure_loc\n        FrameProbe.pop(this.probe_id, this.csp)\n        e.next"),
    ("        if this.sp >= 0\n        {\n            set this.sp: this.sp - 1\n            return *(this.sbase + this.sp)\n        }",
     "        FrameProbe.eval_end(this.probe_id)\n"
     "        if this.sp >= 0\n        {\n            set this.sp: this.sp - 1\n            return *(this.sbase + this.sp)\n        }")])

patch('/packages/dazzle/0.1.0/dazzle/Primitive.scaly', [
    ("use dazzle.GroveManager.GroveManager",
     "use dazzle.FrameProbe.FrameProbe\nuse dazzle.GroveManager.GroveManager"),
    ("    {\n        let host interp.get_host()\n        let a0 *args",
     "    {\n        var host interp.get_host()\n"
     "        ; DZ_FRAME_PROBE: a sampled call of a probed primitive gets its own\n"
     "        ; page, so the probe can watch what happens to the result after the\n"
     "        ; frame that made it returns.\n"
     "        if FrameProbe.probed(id)\n"
     "        {\n"
     "            let vmid ctx.get_probe_id()\n"
     "            let csp ctx.get_csp()\n"
     "            set host: FrameProbe.probe_host(id, vmid, csp, host)\n"
     "        }\n"
     "        let a0 *args")])

patch('/tools/link-lto.sh', [(
    '"$WORK/whole.o" "$WORK/fcontext.o" "$WORK/eio.o" "$WORK/ctime.o" -o "$OUT"',
    '"$WORK/whole.o" "$WORK/fcontext.o" "$WORK/eio.o" "$WORK/ctime.o" ${LTO_EXTRA_OBJS:-} -o "$OUT"')])

patch('/packages/dazzle/0.1.0/dazzle/Interpreter.scaly', [
    ("use dazzle.NameTable.NameTable",
     "use dazzle.FrameProbe.FrameProbe\nuse dazzle.NameTable.NameTable"),
    ("    procedure set_eval_region(this: pointer[Interpreter], p: pointer[Page])\n        set eval_region: p",
     "    procedure set_eval_region(this: pointer[Interpreter], p: pointer[Page])\n    {\n"
     "        ; DZ_FRAME_PROBE: each eval bracket is a generation, which is what\n"
     "        ; separates \"used inside its construction rule\" from \"outlived it\".\n"
     "        FrameProbe.gen_bump()\n"
     "        set eval_region: p\n    }")])
PY

# the shim object, then build-cli.sh's LTO link with it appended
TMP="$(mktemp -d)"
${CLANG:-clang} -O2 -c "$HERE/frameprobe.c" -o "$TMP/frameprobe.o" || { echo "frameprobe: FAIL (shim)"; exit 1; }
cd "$WT"
if ! LTO_EXTRA_OBJS="$TMP/frameprobe.o" tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$TMP/build.log" 2>&1; then
  echo "frameprobe: FAIL (build)"; tail -12 "$TMP/build.log"; rm -rf "$TMP"; exit 1
fi
rm -rf "$TMP"
echo "frameprobe: built $OUT (run it with DZ_FRAME_PROBE=1; see $HERE/README.md)"
