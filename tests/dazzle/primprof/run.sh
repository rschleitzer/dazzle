#!/usr/bin/env bash
# tests/dazzle/primprof/run.sh — build a per-PRIMITIVE time-profile build of
# the dazzle CLI.
#
#   tests/dazzle/primprof/run.sh <out-binary> [scalyc-binary]
#     … then run <out-binary> with DZ_PRIM_PROF=1 (see README.md).
#
# Same shape as tests/dazzle/frameprobe/run.sh and for the same reason: the
# probe is not part of the shipped engine, so the instrumented engine is
# assembled out of the tree instead of into it —
#
#   1. a git worktree at HEAD (the tree you are working in stays untouched),
#   2. PrimProf.scaly copied into the dazzle package + declared as a module,
#   3. the hooks inserted by exact string replacement. A replacement whose
#      anchor is gone fails LOUDLY: that means the engine moved and the hook
#      needs re-aiming, not that the probe is broken,
#   4. the whole-program LTO link of build-cli.sh, with primprof.o appended.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-/tmp/dazzle-primprof}"
BIN="${2:-$ROOT/scalyc/build/scalyc}"
WT="$(mktemp -d)/wt"

cd "$ROOT"
git worktree add --detach "$WT" HEAD > /dev/null 2>&1 || { echo "primprof: FAIL (worktree)"; exit 1; }
trap 'cd "$ROOT"; git worktree remove --force "$WT" >/dev/null 2>&1; rm -rf "$(dirname "$WT")"' EXIT

cp "$HERE/PrimProf.scaly" "$WT/packages/dazzle/0.1.0/dazzle/PrimProf.scaly"

python3 - "$WT" <<'PY' || { echo "primprof: FAIL (hooks — an anchor moved, re-aim it)"; exit 1; }
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

# 1. the module, declared first — it depends on nothing at all (four externs).
patch('/packages/dazzle/0.1.0/dazzle.scaly', [(
    "    ; The frame mark (DAZZLE_FRAME_MARK). Declared FIRST:",
    "    ; the DZ_PRIM_PROF per-primitive time profile (tests/dazzle/primprof).\n"
    "    ; Declared FIRST: ELObj and Interpreter call into it, and it depends on\n"
    "    ; nothing whatsoever.\n"
    "    module PrimProf\n"
    "    ; The frame mark (DAZZLE_FRAME_MARK). Declared FIRST:")])

# 2. the one and only call site of Primitive.dispatch. Every primitive
#    invocation in the engine funnels through ELObj.prim_call — the Insn arm,
#    PrimitiveObj::call, PrimitiveObj::tailCall and the JIT's jit_prim_call all
#    call it — so this single bracket covers the whole population in both
#    --interp and --jit mode.
patch('/packages/dazzle/0.1.0/dazzle/ELObj.scaly', [
    ("use dazzle.Primitive.Primitive",
     "use dazzle.Primitive.Primitive\nuse dazzle.PrimProf.PrimProf"),
    ("                return Primitive.dispatch(p.prim_id, nm, n_args, args, ctx, interp, loc)",
     "                ; DZ_PRIM_PROF: publish which primitive is running, so the\n"
     "                ; ITIMER_PROF sampler can attribute cpu to it. The previous\n"
     "                ; occupant is restored, which makes the figure SELF time.\n"
     "                let pp_prev PrimProf.enter(p.prim_id)\n"
     "                let pp_res Primitive.dispatch(p.prim_id, nm, n_args, args, ctx, interp, loc)\n"
     "                PrimProf.leave(pp_prev)\n"
     "                return pp_res")])

# 3. names for the report + arming the timer once, at engine setup.
patch('/packages/dazzle/0.1.0/dazzle/Interpreter.scaly', [
    ("use dazzle.NameTable.NameTable",
     "use dazzle.PrimProf.PrimProf\nuse dazzle.NameTable.NameTable"),
    ("    function install_primitive(this: pointer[Interpreter], name: pointer[const_char], prim_id: int, sig: Signature)\n"
     "    {\n"
     "        let ident this.lookup(StringC(name))",
     "    function install_primitive(this: pointer[Interpreter], name: pointer[const_char], prim_id: int, sig: Signature)\n"
     "    {\n"
     "        PrimProf.name_id(name, prim_id)\n"
     "        let ident this.lookup(StringC(name))"),
    ("    function install_x_primitive(this: pointer[Interpreter], prefix: pointer[const_char], name: pointer[const_char], prim_id: int, sig: Signature)\n"
     "    {\n"
     "        let ident this.lookup(StringC(name))",
     "    function install_x_primitive(this: pointer[Interpreter], prefix: pointer[const_char], name: pointer[const_char], prim_id: int, sig: Signature)\n"
     "    {\n"
     "        PrimProf.name_id(name, prim_id)\n"
     "        let ident this.lookup(StringC(name))"),
    ("    function install_primitives(this: pointer[Interpreter])\n    {\n",
     "    function install_primitives(this: pointer[Interpreter])\n    {\n"
     "        PrimProf.start()\n")])

# 4. the shim object on the LTO link line, ahead of -lm (a left-to-right ELF
#    linker only pulls a library for symbols undefined so far).
patch('/tools/link-lto.sh', [(
    '"$WORK/whole.o" "$WORK/fcontext.o" "$WORK/eio.o" "$WORK/ctime.o" ${EXTRA[@]+"${EXTRA[@]}"} -lm -o "$OUT"',
    '"$WORK/whole.o" "$WORK/fcontext.o" "$WORK/eio.o" "$WORK/ctime.o" ${LTO_EXTRA_OBJS:-} ${EXTRA[@]+"${EXTRA[@]}"} -lm -o "$OUT"')])
PY

TMP="$(mktemp -d)"
${CLANG:-clang} -O2 -c "$HERE/primprof.c" -o "$TMP/primprof.o" || { echo "primprof: FAIL (shim)"; rm -rf "$TMP"; exit 1; }
cd "$WT"
if ! LTO_EXTRA_OBJS="$TMP/primprof.o" tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$TMP/build.log" 2>&1; then
  echo "primprof: FAIL (build)"; tail -20 "$TMP/build.log"; rm -rf "$TMP"; exit 1
fi
rm -rf "$TMP"
echo "primprof: built $OUT (run it with DZ_PRIM_PROF=1; see $HERE/README.md)"
