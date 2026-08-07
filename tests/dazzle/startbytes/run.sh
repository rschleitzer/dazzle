#!/usr/bin/env bash
# tests/dazzle/startbytes/run.sh — build an arena-attribution probe of the
# dazzle CLI and run something with it.  See README.md.
#
#   tests/dazzle/startbytes/run.sh [out-binary] [scalyc-binary]
#     … then run <out-binary> with DZ_START_BYTES=1.
#
# It answers "where do the bytes of a run come from", by SORT and by PHASE:
# every bump allocation is charged to the phase bracket that is live, with a
# per-phase histogram over the requested SIZE (so a record type is named by its
# sizeof, which the probe prints), and it separates
#   * REQUESTED bytes from REGION bytes  -> the page slack is a subtraction,
#   * allocated from FREED               -> live at the peak, not just at exit,
#   * the phases                         -> parse scaffolding from the live
#                                           compiled representation.
#
# Unlike frameprobe/framevol this probe hooks the ALLOCATOR
# (packages/scaly/…/memory/Page.scaly) as well as the engine, so the throwaway
# build's runtime archive is rebuilt from the worktree — that is why run.sh
# deletes /tmp/libscaly.a before building, and why you should delete it again
# afterwards before building anything you intend to measure.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-/tmp/dazzle-startbytes}"
BIN="${2:-$ROOT/scalyc/build/scalyc}"
WT="$(mktemp -d)/wt"
cd "$ROOT"
git worktree add --detach "$WT" HEAD >/dev/null 2>&1 || { echo "FAIL (worktree)"; exit 1; }
trap 'cd "$ROOT"; git worktree remove --force "$WT" >/dev/null 2>&1; rm -rf "$(dirname "$WT")"' EXIT

python3 - "$WT" <<'PY' || { echo "FAIL (hooks — an anchor moved, re-aim it)"; exit 1; }
import sys
wt = sys.argv[1]

def patch(path, pairs):
    p = wt + path
    s = open(p).read()
    for old, new in pairs:
        if old not in s:
            raise SystemExit("anchor not found in %s:\n%s" % (path, old[:200]))
        s = s.replace(old, new, 1)
    open(p, 'w').write(s)

PROBE = r'''
; --- STARTBYTES probe (throwaway measurement build) -----------------------
function getenv(name: pointer[const_char]) returns pointer[const_char] extern
function calloc(count: size_t, size: size_t) returns pointer[void] extern
procedure atexit(cb: pointer[void]) returns i32 extern

define SB_NPHASE: i64 12
define SB_NSIZE: i64 1024

shared sb_state: int 0
shared sb_on: bool false
shared sb_cur: i64 0
shared sb_bytes: pointer[i64] null
shared sb_count: pointer[i64] null
shared sb_hist: pointer[i64] null
shared sb_bigb: pointer[i64] null
shared sb_bigc: pointer[i64] null
shared sb_ovb: pointer[i64] null
shared sb_ovc: pointer[i64] null
shared sb_ovr: pointer[i64] null
shared sb_pagesph: pointer[i64] null
shared sb_pages: i64 0
shared sb_live: i64 0
shared sb_maxlive: i64 0
; the LIVE / GARBAGE separation for the big half: oversized blocks by log2
; class, and how many of them ever come back through release_page.
shared sb_ovhist: pointer[i64] null
shared sb_ovhistb: pointer[i64] null
shared sb_freedc: i64 0
shared sb_freedb: i64 0
shared sb_relpages: i64 0
; PEAK, which is the number the RSS column shows: live HeapBucket pages plus
; live oversized bytes, with a running maximum and the phase that held it.
shared sb_livebytes: i64 0
shared sb_peak: i64 0
shared sb_peakph: i64 0
shared sb_peakat: pointer[i64] null

function sb_atexit()
    Page.sb_report()

procedure sb_tick(size: size_t)
{
    let ph sb_cur
    let b sb_bytes
    let c sb_count
    set *(b + ph): *(b + ph) + (size as i64)
    set *(c + ph): *(c + ph) + 1
    if (size as i64) < SB_NSIZE
    {
        let h sb_hist
        let i (ph * SB_NSIZE) + (size as i64)
        set *(h + i): *(h + i) + 1
    }
    if (size as i64) >= SB_NSIZE
    {
        let bb sb_bigb
        let bc sb_bigc
        set *(bb + ph): *(bb + ph) + (size as i64)
        set *(bc + ph): *(bc + ph) + 1
    }
}

procedure sb_tick_over(size: size_t, rounded: size_t)
{
    let ph sb_cur
    let ob sb_ovb
    let oc sb_ovc
    let orr sb_ovr
    set *(ob + ph): *(ob + ph) + (size as i64)
    set *(oc + ph): *(oc + ph) + 1
    set *(orr + ph): *(orr + ph) + (rounded as i64)
    ; log2 class of the rounded block, per phase
    var k: i64 0
    var v (rounded as i64) >> 12
    while v > 1
    {
        set v: v >> 1
        set k: k + 1
    }
    if k > 23
        set k: 23
    let oh sb_ovhist
    let ohb sb_ovhistb
    let idx (ph * 24) + k
    set *(oh + idx): *(oh + idx) + 1
    set *(ohb + idx): *(ohb + idx) + (rounded as i64)
    sb_grow(rounded as i64)
}

; the running maximum of live bytes, and WHO held it
procedure sb_grow(n: i64)
{
    set sb_livebytes: sb_livebytes + n
    if sb_livebytes > sb_peak
    {
        set sb_peak: sb_livebytes
        set sb_peakph: sb_cur
    }
}

; the other end of the same question: does an oversized block ever come back?
procedure sb_tick_free(bytes: i64)
{
    set sb_freedc: sb_freedc + 1
    set sb_freedb: sb_freedb + bytes
    set sb_livebytes: sb_livebytes - bytes
}
'''

REPORT = r'''
    ; --- STARTBYTES probe: the reporting half -----------------------------
    procedure sb_setup()
    {
        set sb_state: 2
        let e getenv("DZ_START_BYTES")
        if e = null
            return
        set sb_bytes: calloc(SB_NPHASE as size_t, 8) as pointer[i64]
        set sb_count: calloc(SB_NPHASE as size_t, 8) as pointer[i64]
        set sb_bigb: calloc(SB_NPHASE as size_t, 8) as pointer[i64]
        set sb_bigc: calloc(SB_NPHASE as size_t, 8) as pointer[i64]
        set sb_ovb: calloc(SB_NPHASE as size_t, 8) as pointer[i64]
        set sb_ovc: calloc(SB_NPHASE as size_t, 8) as pointer[i64]
        set sb_ovr: calloc(SB_NPHASE as size_t, 8) as pointer[i64]
        set sb_pagesph: calloc(SB_NPHASE as size_t, 8) as pointer[i64]
        set sb_ovhist: calloc((SB_NPHASE * 24) as size_t, 8) as pointer[i64]
        set sb_ovhistb: calloc((SB_NPHASE * 24) as size_t, 8) as pointer[i64]
        set sb_peakat: calloc(SB_NPHASE as size_t, 8) as pointer[i64]
        set sb_hist: calloc((SB_NPHASE * SB_NSIZE) as size_t, 8) as pointer[i64]
        if sb_hist = null
            return
        if sb_ovhistb = null
            return
        atexit(&sb_atexit)
        set sb_state: 1
        set sb_on: true
    }

    function sb_phase(k: i64) returns i64
    {
        if sb_state = 0
            Page.sb_setup()
        let old sb_cur
        ; live bytes AT the transition — the shape of the curve, which is what
        ; says whether a phase's bytes are still there when the next one runs
        let pa sb_peakat
        set *(pa + k): sb_livebytes
        set sb_cur: k
        old
    }

    function sb_is_on() returns bool
    {
        if sb_state = 0
            Page.sb_setup()
        sb_on
    }

    procedure sb_name(k: i64)
    {
        if k = 0
            scaly_eputs "other       "
        if k = 1
            scaly_eputs "engine      "
        if k = 2
            scaly_eputs "sgmlparse   "
        if k = 3
            scaly_eputs "scheme      "
        if k = 4
            scaly_eputs "compile     "
        if k = 5
            scaly_eputs "style       "
        if k = 6
            scaly_eputs "specassemble"
        if k = 7
            scaly_eputs "docparse    "
        if k = 8
            scaly_eputs "extspecparse"
        if k = 9
            scaly_eputs "walk+gather "
        if k = 10
            scaly_eputs "phase10     "
        if k = 11
            scaly_eputs "phase11     "
    }

    procedure sb_line(name: pointer[const_char], v: i64)
    {
        scaly_eputs "  "
        scaly_eputs name
        scaly_eputs " "
        scaly_eputi v
        scaly_eputnl()
    }

    procedure sb_report()
    {
        if sb_on = false
            return
        let b sb_bytes
        let c sb_count
        let bb sb_bigb
        let bc sb_bigc
        let ob sb_ovb
        let oc sb_ovc
        let orr sb_ovr
        let pp sb_pagesph
        let h sb_hist
        var tb: i64 0
        var tov: i64 0
        var tovr: i64 0
        var i: i64 0
        while i < SB_NPHASE
        {
            set tb: tb + *(b + i)
            set tov: tov + *(ob + i)
            set tovr: tovr + *(orr + i)
            set i: i + 1
        }
        scaly_eputs "startbytes: requested "
        scaly_eputi(tb / 1048576)
        scaly_eputs " MB total, of which oversized requests "
        scaly_eputi(tov / 1048576)
        scaly_eputs " MB (rounded to "
        scaly_eputi(tovr / 1048576)
        scaly_eputs " MB of aligned_alloc)"
        scaly_eputnl()
        scaly_eputs "startbytes: bump requested "
        scaly_eputi((tb - tov) / 1048576)
        scaly_eputs " MB in "
        scaly_eputi sb_pages
        scaly_eputs " pages handed out ("
        scaly_eputi(sb_pages * (PAGE_SIZE as i64) / 1048576)
        scaly_eputs " MB), max live "
        scaly_eputi(sb_maxlive * (PAGE_SIZE as i64) / 1048576)
        scaly_eputs " MB  => region total "
        scaly_eputi((sb_maxlive * (PAGE_SIZE as i64) + tovr) / 1048576)
        scaly_eputs " MB"
        scaly_eputnl()
        scaly_eputs "startbytes: PEAK live "
        scaly_eputi(sb_peak / 1048576)
        scaly_eputs " MB, reached in phase "
        Page.sb_name sb_peakph
        scaly_eputs ";  live at exit "
        scaly_eputi(sb_livebytes / 1048576)
        scaly_eputs " MB"
        scaly_eputnl()
        let pa sb_peakat
        set i: 0
        while i < SB_NPHASE
        {
            if *(pa + i) > 0
            {
                scaly_eputs "  live bytes when phase "
                Page.sb_name i
                scaly_eputs " last began: "
                scaly_eputi(*(pa + i) / 1048576)
                scaly_eputs " MB"
                scaly_eputnl()
            }
            set i: i + 1
        }
        set i: 0
        scaly_eputs "startbytes: pages released "
        scaly_eputi sb_relpages
        scaly_eputs " of "
        scaly_eputi sb_pages
        scaly_eputs ";  oversized blocks freed "
        scaly_eputi sb_freedc
        scaly_eputs " = "
        scaly_eputi(sb_freedb / 1048576)
        scaly_eputs " MB  => oversized LIVE at end "
        scaly_eputi((tovr - sb_freedb) / 1048576)
        scaly_eputs " MB"
        scaly_eputnl()
        let oh sb_ovhist
        let ohb sb_ovhistb
        set i: 0
        while i < SB_NPHASE
        {
            if *(oc + i) > 0
            {
                scaly_eputs "  oversized classes of phase "
                Page.sb_name i
                scaly_eputnl()
                var k: i64 0
                while k < 24
                {
                    if *(oh + (i * 24) + k) > 0
                    {
                        scaly_eputs "      "
                        scaly_eputi(4 << k)
                        scaly_eputs " KB class x "
                        scaly_eputi(*(oh + (i * 24) + k))
                        scaly_eputs " = "
                        scaly_eputi(*(ohb + (i * 24) + k) / 1048576)
                        scaly_eputs " MB"
                        scaly_eputnl()
                    }
                    set k: k + 1
                }
            }
            set i: i + 1
        }
        set i: 0
        while i < SB_NPHASE
        {
            if *(c + i) > 0
            {
                scaly_eputs "  phase "
                Page.sb_name i
                scaly_eputs "  allocs "
                scaly_eputi(*(c + i))
                scaly_eputs "  requested "
                scaly_eputi(*(b + i) / 1048576)
                scaly_eputs " MB  (oversized "
                scaly_eputi(*(ob + i) / 1048576)
                scaly_eputs " MB in "
                scaly_eputi(*(oc + i))
                scaly_eputs " blocks)  pages "
                scaly_eputi(*(pp + i))
                scaly_eputs " = "
                scaly_eputi(*(pp + i) * (PAGE_SIZE as i64) / 1048576)
                scaly_eputs " MB  >=1024B "
                scaly_eputi(*(bc + i))
                scaly_eputs " allocs / "
                scaly_eputi(*(bb + i) / 1048576)
                scaly_eputs " MB"
                scaly_eputnl()
                var shown: i64 0
                var cut: i64 0
                while shown < 14
                {
                    var best: i64 (0 - 1)
                    var bestv: i64 0
                    var s: i64 0
                    while s < SB_NSIZE
                    {
                        let v *(h + (i * SB_NSIZE) + s) * s
                        if v > bestv
                        {
                            if cut = 0
                            {
                                set bestv: v
                                set best: s
                            }
                            if cut > 0
                            {
                                if v < cut
                                {
                                    set bestv: v
                                    set best: s
                                }
                            }
                        }
                        set s: s + 1
                    }
                    if best < 0
                        set shown: 14
                    if best >= 0
                    {
                        scaly_eputs "      size "
                        scaly_eputi best
                        scaly_eputs " x "
                        scaly_eputi(*(h + (i * SB_NSIZE) + best))
                        scaly_eputs " = "
                        scaly_eputi(bestv / 1024)
                        scaly_eputs " KB ("
                        scaly_eputi(bestv * 100 / (*(b + i) + 1))
                        scaly_eputs " %)"
                        scaly_eputnl()
                        set cut: bestv
                        set shown: shown + 1
                    }
                }
            }
            set i: i + 1
        }
    }
'''

patch('/packages/scaly/0.1.0/scaly/memory/Page.scaly', [
    ("; `region` is appended LAST on purpose:", PROBE + "\n; `region` is appended LAST on purpose:"),
    ("    function allocate(this: Page, size: size_t, align: size_t) returns pointer[void]\n    {\n        let location next_object as size_t",
     "    function allocate(this: Page, size: size_t, align: size_t) returns pointer[void]\n    {\n"
     "        ; ARMED AT THE FIRST ALLOCATION, not at the first bracket: the DTD\n"
     "        ; parse runs before any bracket, and a probe that starts late\n"
     "        ; counts releases it never saw allocated (62431 releases of 52202\n"
     "        ; pages was exactly that).\n"
     "        if sb_state = 0\n            Page.sb_setup()\n"
     "        if sb_on\n            sb_tick(size)\n"
     "        let location next_object as size_t"),
    ("        let rounded (size + PAGE_SIZE - 1) & (~(PAGE_SIZE - 1))\n        let address aligned_alloc(PAGE_SIZE, rounded)",
     "        let rounded (size + PAGE_SIZE - 1) & (~(PAGE_SIZE - 1))\n"
     "        if sb_on\n            sb_tick_over(size, rounded)\n"
     "        let address aligned_alloc(PAGE_SIZE, rounded)"),
    ("        let page_addr (b as size_t) + ((slot + 1) as size_t) * PAGE_SIZE\n        let page page_addr as pointer[Page]",
     "        if sb_on\n        {\n            set sb_pages: sb_pages + 1\n"
     "            set sb_live: sb_live + 1\n"
     "            let pp sb_pagesph\n            set *(pp + sb_cur): *(pp + sb_cur) + 1\n"
     "            if sb_live > sb_maxlive\n                set sb_maxlive: sb_live\n"
     "            sb_grow(PAGE_SIZE as i64)\n        }\n"
     "        let page_addr (b as size_t) + ((slot + 1) as size_t) * PAGE_SIZE\n        let page page_addr as pointer[Page]"),
    ("    function release_page(p: pointer[Page])\n    {",
     "    function release_page(p: pointer[Page])\n    {\n"
     "        if sb_on\n        {\n"
     "            ; an oversized block is NOT a HeapBucket page — it was never\n"
     "            ; counted in sb_pages, so it must not decrement sb_live either.\n"
     "            if p.next_object = null\n                sb_tick_free(Page.oversized_size(p) as i64)\n"
     "            if p.next_object <> null\n            {\n"
     "                set sb_live: sb_live - 1\n"
     "                set sb_relpages: sb_relpages + 1\n"
     "                set sb_livebytes: sb_livebytes - (PAGE_SIZE as i64)\n            }\n        }"),
    ("    ; Attributed variants of allocate_page/release_page for the",
     REPORT + "\n    ; Attributed variants of allocate_page/release_page for the"),
])

# ---- the oversized charge must not ALSO be charged as a bump request ------
# `allocate` charges `size` before delegating; subtract it back in the
# oversized hook so the two columns are disjoint.
patch('/packages/scaly/0.1.0/scaly/memory/Page.scaly', [
    ("procedure sb_tick_over(size: size_t, rounded: size_t)\n{\n    let ph sb_cur",
     "procedure sb_tick_over(size: size_t, rounded: size_t)\n{\n"
     "    ; `allocate` already charged this request as a bump request (it did not\n"
     "    ; know yet that it would go oversized) — take it back out.\n"
     "    let phb sb_cur\n    let bb sb_bytes\n    let cc sb_count\n"
     "    set *(bb + phb): *(bb + phb) - ((size - sizeof Page) as i64)\n"
     "    set *(cc + phb): *(cc + phb) - 1\n"
     "    let ph sb_cur"),
])

# 8 = the child SGML parse of an EXTERNAL SPECIFICATION document (37 of them
#     in the DocBook print stylesheet), 9 = the event sweep that gathers body
#     text. Both nest inside phase 6.
patch('/packages/dazzle/0.1.0/dazzle/DssslSpecEventHandler.scaly', [
    ("        if this.got_arc\n            this.walk(ps)",
     "        if this.got_arc\n        {\n            let sb_w Page.sb_phase(9)\n"
     "            this.walk(ps)\n            Page.sb_phase(sb_w)\n        }"),
    ("    function load_external_doc(this: pointer[DssslSpecEventHandler], doc: pointer[Doc])\n    {\n        let host this.host",
     "    function load_external_doc(this: pointer[DssslSpecEventHandler], doc: pointer[Doc])\n    {\n"
     "        let sb_x Page.sb_phase(8)\n        this.load_external_doc_inner(doc)\n"
     "        Page.sb_phase(sb_x)\n    }\n\n"
     "    function load_external_doc_inner(this: pointer[DssslSpecEventHandler], doc: pointer[Doc])\n    {\n        let host this.host"),
])

# ---------------------------------------------------------------- brackets
patch('/packages/dazzle/0.1.0/dazzle_cli.scaly', [
    ("    let gs GroveBuilder.begin(host, 0)",
     "    let sb_d Page.sb_phase(7)\n    let gs GroveBuilder.begin(host, 0)"),
    ("    let root GroveBuilder.finish(gs)",
     "    let root GroveBuilder.finish(gs)\n    Page.sb_phase(sb_d)"),
    ("use opensp.Parser.Parser",
     "use opensp.Event.Event\nuse opensp.Location.Location\nuse opensp.Attribute.Attribute\n"
     "use opensp.AttributeList.AttributeList\nuse opensp.Location.TextChunk\nuse opensp.Parser.Parser"),
    ("    let interp Interpreter.make(host, upi, debug, dsssl2, strict)",
     "    if Page.sb_is_on()\n    {\n"
     "        Page.sb_line(\"sizeof Event       \", sizeof Event as i64)\n"
     "        Page.sb_line(\"sizeof Location    \", sizeof Location as i64)\n"
     "        Page.sb_line(\"sizeof StringC     \", sizeof StringC as i64)\n"
     "        Page.sb_line(\"sizeof Attribute   \", sizeof Attribute as i64)\n"
     "        Page.sb_line(\"sizeof AttributeList\", sizeof AttributeList as i64)\n"
     "        Page.sb_line(\"sizeof TextChunk   \", sizeof TextChunk as i64)\n"
     "        Page.sb_line(\"sizeof GroveNode   \", sizeof GroveNode as i64)\n"
     "    }\n"
     "    let sb_e Page.sb_phase(1)\n    let interp Interpreter.make(host, upi, debug, dsssl2, strict)"),
    ("    let vcmd vsb.to_string()",
     "    Page.sb_phase(sb_e)\n    let vcmd vsb.to_string()"),
    ("    interp.compile()",
     "    let sb_c Page.sb_phase(4)\n    interp.compile()\n    Page.sb_phase(sb_c)"),
    ("        let pcf ProcessContext.make_fot(host, interp, sgml)\n        pcf.process(root)",
     "        let pcf ProcessContext.make_fot(host, interp, sgml)\n"
     "        let sb_s Page.sb_phase(5)\n        pcf.process(root)\n        Page.sb_phase(sb_s)"),
    # 2 = the SGML parse of the TOP .dsl only
    ("    let ps Parser.parse_simple_cat(host, dsl_path, prog_name, catalog_path, extra_cats, search_dirs, restrict_reading)",
     "    let sb_p Page.sb_phase(2)\n"
     "    let ps Parser.parse_simple_cat(host, dsl_path, prog_name, catalog_path, extra_cats, search_dirs, restrict_reading)\n"
     "    Page.sb_phase(sb_p)"),
    # 6 = eh.load: part assembly + every external specification's child parse
    ("    let parts eh.load(ps, dsl_id)\n    if parts = null\n        return false",
     "    let sb_l Page.sb_phase(6)\n    let parts eh.load(ps, dsl_id)\n    Page.sb_phase(sb_l)\n"
     "    if parts = null\n        return false"),
    ("                let bsp SchemeParser.make(host, interp, bsrc)\n                bsp.parse()",
     "                let sb_s Page.sb_phase(3)\n"
     "                let bsp SchemeParser.make(host, interp, bsrc)\n                bsp.parse()\n"
     "                Page.sb_phase(sb_s)"),
])
PY

TMP="$(mktemp -d)"
cd "$WT"
rm -f /tmp/libscaly.a /tmp/libscaly.ll
if ! tests/dazzle/build-cli.sh "$OUT" "$BIN" > "$TMP/build.log" 2>&1; then
  echo "FAIL (build)"; tail -30 "$TMP/build.log"; rm -rf "$TMP"; exit 1
fi
rm -rf "$TMP"
echo "startbytes: built $OUT  (run with DZ_START_BYTES=1)"
