#!/usr/bin/env bash
# tests/dazzle/framemark/run.sh — build a FRAME-MARK build of the dazzle CLI.
#
#   tests/dazzle/framemark/run.sh <out-binary> [scalyc-binary]
#     … then run <out-binary> with DZ_FRAME_MARK=dry (accounting only) or
#     DZ_FRAME_MARK=1 (actually rewind). See README.md.
#
# Same shape as framevol/frameprobe: a git worktree at HEAD plus exact string
# replacements, so the tree you are working in stays untouched and nothing in
# the shipped build scripts knows about this. Seven hooks:
#
#   VM.push_frame            take the mark
#   VM.unwind_control_stack  a call/cc unwind publishes
#   Insn Return arm          the rewind decision (it has the result)
#   Insn SetBox/StackSetBox/ClosureSetBox   publish (a box can be any frame's)
#   Insn StackSet/SetImmediate              publish only under
#                                           DZ_FRAME_MARK_PUBLISH_STACK
#   Jit jit_pop_frame        the same decision on the JIT's native Return, whose
#                            lowering already has the result in hand — the call
#                            goes from call1 to call2, no extra call
#   Primitive.dispatch       every primitive publishes unless trusted
#   Interpreter.set_eval_region   the bracket generation
#   ELObj (2 sites)          a frame popped without a reported result
#
# A replacement whose anchor is gone fails LOUDLY — the engine moved and the
# hook needs re-aiming, the instrument is not broken.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-/tmp/dazzle-framemark}"
BIN="${2:-$ROOT/scalyc/build/scalyc}"
WT="$(mktemp -d)/wt"

cd "$ROOT"
git worktree add --detach "$WT" HEAD > /dev/null 2>&1 || { echo "framemark: FAIL (worktree)"; exit 1; }
trap 'cd "$ROOT"; git worktree remove --force "$WT" >/dev/null 2>&1; rm -rf "$(dirname "$WT")"' EXIT

cp "$HERE/FrameMark.scaly" "$WT/packages/dazzle/0.1.0/dazzle/FrameMark.scaly"

python3 - "$WT" <<'PY' || { echo "framemark: FAIL (hooks — an anchor moved, re-aim it)"; exit 1; }
import sys
wt = sys.argv[1]
def patch(path, pairs):
    # each pair is (old, new) or (old, new, expected_hits) — an anchor that
    # matches a different number of times than expected fails LOUDLY rather
    # than patching the wrong site (StackSetBox and ClosureSetBox share a body
    # shape, which is exactly how this guard earned its place).
    p = wt + path
    s = open(p).read()
    for pair in pairs:
        old, new = pair[0], pair[1]
        want = pair[2] if len(pair) > 2 else 1
        got = s.count(old)
        if got != want:
            raise SystemExit("anchor in %s matched %d times, expected %d:\n%s"
                             % (path, got, want, old))
        s = s.replace(old, new, want)
    open(p, 'w').write(s)

patch('/packages/dazzle/0.1.0/dazzle.scaly', [(
    "    ; NamedTable<T> (generic/NamedTable.h) — the hash-probed name index behind",
    "    ; the DZ_FRAME_MARK frame-mark hook (tests/dazzle/framemark). Declared\n"
    "    ; FIRST: VM, Insn, Primitive, Interpreter, ELObj and Jit call into it, and\n"
    "    ; it depends on nothing but Page.\n"
    "    module FrameMark\n"
    "    ; NamedTable<T> (generic/NamedTable.h) — the hash-probed name index behind")])

patch('/packages/dazzle/0.1.0/dazzle/VM.scaly', [
    ("use dazzle.ELObj.GlyphSubstTableRec",
     "use dazzle.ELObj.GlyphSubstTableRec\nuse dazzle.FrameMark.FrameMark"),
    ("        set e.continuation: null\n        set this.csp: this.csp + 1\n    }",
     "        set e.continuation: null\n        set this.csp: this.csp + 1\n"
     "        FrameMark.push(this.csp)\n    }"),
    # a call/cc unwind drops frames without a Return: nothing above any live
    # mark can be trusted afterwards
    ("    function unwind_control_stack(this: pointer[VM], target_csp: int)\n    {",
     "    function unwind_control_stack(this: pointer[VM], target_csp: int)\n    {\n"
     "        if this.csp > target_csp\n            FrameMark.publish()")])

patch('/packages/dazzle/0.1.0/dazzle/Insn.scaly', [
    ("use dazzle.ELObj.ELObj",
     "use dazzle.FrameMark.FrameMark\nuse dazzle.ELObj.ELObj"),
    # the rewind decision — csp is still the leaving frame's
    ("                let result vm.stack_ref(vm.get_sp() - 1)\n"
     "                vm.set_sp(vm.get_sp() - 1 - ri.total_args)\n"
     "                let nxt vm.pop_frame()",
     "                let result vm.stack_ref(vm.get_sp() - 1)\n"
     "                vm.set_sp(vm.get_sp() - 1 - ri.total_args)\n"
     "                FrameMark.pop(vm.get_csp(), result as pointer[void])\n"
     "                let nxt vm.pop_frame()"),
    # a box may belong to any enclosing frame -> publication
    ("                let box vm.stack_ref(vm.get_sp() - sbx.n)\n"
     "                box.box_set_value(vm.stack_ref(vm.get_sp()))",
     "                let box vm.stack_ref(vm.get_sp() - sbx.n)\n"
     "                FrameMark.publish()\n"
     "                box.box_set_value(vm.stack_ref(vm.get_sp()))"),
    # StackSetBox AND ClosureSetBox — same body shape, both are box writes,
    # both publish. Patched together and pinned at 2 hits.
    ("                let tem box.box_value()\n"
     "                box.box_set_value(vm.stack_ref(vm.get_sp() - 1))",
     "                let tem box.box_value()\n"
     "                FrameMark.publish()\n"
     "                box.box_set_value(vm.stack_ref(vm.get_sp() - 1))", 2),
    # value-stack writes: only under DZ_FRAME_MARK_PUBLISH_STACK
    ("            when si: SetImmediate\n            {\n                vm.set_sp(vm.get_sp() - 1)",
     "            when si: SetImmediate\n            {\n"
     "                FrameMark.publish_stack()\n                vm.set_sp(vm.get_sp() - 1)"),
    ("            when ss: StackSet\n            {\n                let tem vm.stack_ref(vm.get_sp() + ss.index)",
     "            when ss: StackSet\n            {\n"
     "                FrameMark.publish_stack()\n                let tem vm.stack_ref(vm.get_sp() + ss.index)")])

# ★ The AUDIT's hooks: the stores into PRE-EXISTING objects that the five
# audited primitives can reach. All five are pure producers in themselves; what
# they reach is lazy memoisation, and `FrameMark.store` decides per store
# whether it publishes (target in OUR region and below the innermost mark) or
# not (target in the grove's region, or inside the frame's own range).
patch('/packages/dazzle/0.1.0/dazzle/ELObj.scaly', [
    # force_select — `out.add` grows an Array allocated WITH the view, and the
    # growth lands at the eval region's tail, i.e. inside the running frame.
    ("    function force_select(g: pointer[SelectGen], need: int)\n    {\n"
     "        if g.cursor < 0\n            return",
     "    function force_select(g: pointer[SelectGen], need: int)\n    {\n"
     "        if g.cursor < 0\n            return\n"
     "        FrameMark.store(g.out as pointer[void])"),
    ("    procedure concat_fill(list: pointer[ELObj], out: pointer[Array[pointer[GroveNode]]])\n    {\n"
     "        if list = null\n            return",
     "    procedure concat_fill(list: pointer[ELObj], out: pointer[Array[pointer[GroveNode]]])\n    {\n"
     "        if list = null\n            return\n"
     "        FrameMark.store(out as pointer[void])"),
    # the string rope's flatten-and-memoise-in-place. Its comment already says
    # the memoised Str must outlive the caller's host — which is right for
    # BRACKET granularity and not enough for a frame mark, because within one
    # region Page.get(this) resolves to the region TAIL.
    ("                let tmp host.allocate(n * (sizeof u32), alignof u32) as pointer[u32]",
     "                FrameMark.store(this as pointer[void])\n"
     "                let tmp host.allocate(n * (sizeof u32), alignof u32) as pointer[u32]"),
    # Identifier's lazy `builtin` — allocates on Page.get(this) and stores into
    # `this`. Identifiers are interned on the PERM host, so the region test will
    # find it out of scope; hooked so the TEST decides that, not the reading.
    ("        let host Page.get(this as pointer[void])\n"
     "        let b Identifier.make(host, this.name)",
     "        FrameMark.store(this as pointer[void])\n"
     "        let host Page.get(this as pointer[void])\n"
     "        let b Identifier.make(host, this.name)")])

patch('/packages/dazzle/0.1.0/dazzle/Grove.scaly', [
    # set_sdata_view and attr_views — the remaining two grove-side stores that
    # allocate on the target's own page. Grove region, so quiet by the test.
    ("        let gpage Page.get(this as pointer[void])\n"
     "        set this.gi: StringC^gpage(&v, 1)",
     "        FrameMark.store(this as pointer[void])\n"
     "        let gpage Page.get(this as pointer[void])\n"
     "        set this.gi: StringC^gpage(&v, 1)"),
    ("        let gpage Page.get(elem as pointer[void])",
     "        FrameMark.store(elem as pointer[void])\n"
     "        let gpage Page.get(elem as pointer[void])")])

# The three VM setters a primitive can reach. The main VM lives on the run page
# (another region, so quiet); a per-member VM from node-list-map is allocated on
# the eval scratch and BELOW every mark, so those publish — conservatively, the
# test does not look at what is stored.
# All three are single-expression bodies, so adding a statement needs BRACES.
patch('/packages/dazzle/0.1.0/dazzle/VM.scaly', [
    ("    procedure set_current_language(this: pointer[VM], l: pointer[ELObj])\n"
     "        set this.current_language: l",
     "    procedure set_current_language(this: pointer[VM], l: pointer[ELObj])\n    {\n"
     "        FrameMark.store(this as pointer[void])\n"
     "        set this.current_language: l\n    }"),
    ("    function set_current_node(this: pointer[VM], n: pointer[GroveNode])\n"
     "        set this.current_node: n",
     "    function set_current_node(this: pointer[VM], n: pointer[GroveNode])\n    {\n"
     "        FrameMark.store(this as pointer[void])\n"
     "        set this.current_node: n\n    }"),
    ("    function set_processing_mode(this: pointer[VM], m: pointer[void])\n"
     "        set this.processing_mode: m",
     "    function set_processing_mode(this: pointer[VM], m: pointer[void])\n    {\n"
     "        FrameMark.store(this as pointer[void])\n"
     "        set this.processing_mode: m\n    }")])

patch('/packages/dazzle/0.1.0/dazzle/Grove.scaly', [
    ("use scaly.memory.Page", "use scaly.memory.Page\nuse dazzle.FrameMark.FrameMark"),
    # the two grove-side lazy view arrays. Both host on Page.get(node), i.e. the
    # GROVE's region, so `store` will find them out of scope and stay quiet —
    # they are hooked anyway, because that is a property of the grove living in
    # another region, not of the call site.
    ("        let gpage Page.get(chunk as pointer[void])",
     "        FrameMark.store(chunk as pointer[void])\n"
     "        let gpage Page.get(chunk as pointer[void])"),
    ("        let gpage Page.get(asgn as pointer[void])",
     "        FrameMark.store(asgn as pointer[void])\n"
     "        let gpage Page.get(asgn as pointer[void])")])

patch('/packages/dazzle/0.1.0/dazzle/Primitive.scaly', [
    ("use dazzle.GroveManager.GroveManager",
     "use dazzle.FrameMark.FrameMark\nuse dazzle.GroveManager.GroveManager"),
    ("    {\n        let host interp.get_host()\n        let a0 *args",
     "    {\n        let host interp.get_host()\n"
     "        ; DZ_FRAME_MARK: a primitive publishes unless it has been audited\n"
     "        ; not to store into anything it did not allocate itself.\n"
     "        FrameMark.prim(id)\n"
     "        let a0 *args")])

patch('/packages/dazzle/0.1.0/dazzle/Interpreter.scaly', [
    ("use dazzle.NameTable.NameTable",
     "use dazzle.FrameMark.FrameMark\nuse dazzle.NameTable.NameTable"),
    ("    procedure set_eval_region(this: pointer[Interpreter], p: pointer[Page])\n        set eval_region: p",
     "    procedure set_eval_region(this: pointer[Interpreter], p: pointer[Page])\n    {\n"
     "        FrameMark.region(p)\n        set eval_region: p\n    }")])

patch('/packages/dazzle/0.1.0/dazzle/ELObj.scaly', [
    ("use scaly.containers.Array",
     "use scaly.containers.Array\nuse dazzle.FrameMark.FrameMark"),
    ("        vm.set_sp(this.continuation_stack_size() - 1)\n        let nxt vm.pop_frame()",
     "        vm.set_sp(this.continuation_stack_size() - 1)\n"
     "        FrameMark.pop_unknown()\n        let nxt vm.pop_frame()"),
    # prim_tail_call (PrimitiveObj::tailCall) — a primitive in TAIL position, so
    # this is where a DSSSL body that ends in a primitive call leaves its frame.
    # Measured: 89 % of all frames go out here, not through the Return arm, so
    # treating it as "no result reported" would blind the whole instrument. It
    # has the result in hand, so it gets the real decision.
    ("        vm.set_sp(argp - n_caller_args)\n        let nxt vm.pop_frame()",
     "        vm.set_sp(argp - n_caller_args)\n"
     "        FrameMark.pop(vm.get_csp(), result as pointer[void])\n"
     "        let nxt vm.pop_frame()")])

# The JIT's native Return already has the result in a register before it calls
# jit_pop_frame, so the decision costs one extra ARGUMENT, not an extra call.
patch('/packages/dazzle/0.1.0/dazzle/Jit.scaly', [
    ("function jit_pop_frame(vm: pointer[void]) returns pointer[void]\n"
     "{\n"
     "    let v vm as pointer[VM]\n"
     "    v.pop_frame() as pointer[void]\n"
     "}",
     "function jit_pop_frame(vm: pointer[void], result: pointer[void]) returns pointer[void]\n"
     "{\n"
     "    let v vm as pointer[VM]\n"
     "    FrameMark.pop(v.get_csp(), result)\n"
     "    v.pop_frame() as pointer[void]\n"
     "}"),
    ("                let nxt Jit.call1(cg, cg.ty_p_p, cg.p_pop_frame, cg.vm)",
     "                let nxt Jit.call2(cg, cg.ty_p_pp, cg.p_pop_frame, cg.vm, result)")])

patch('/packages/dazzle/0.1.0/dazzle/Jit.scaly', [
    ("use dazzle.VM.VM", "use dazzle.FrameMark.FrameMark\nuse dazzle.VM.VM")])
PY

TMP="$(mktemp -d)"
cd "$WT"
if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$TMP/build.log" 2>&1; then
  echo "framemark: FAIL (build)"; tail -20 "$TMP/build.log"; rm -rf "$TMP"; exit 1
fi
rm -rf "$TMP"
echo "framemark: built $OUT (DZ_FRAME_MARK=dry|1; see $HERE/README.md)"
