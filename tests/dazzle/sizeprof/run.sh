#!/usr/bin/env bash
# tests/dazzle/sizeprof/run.sh — build an allocation-attribution probe of
# `onsgmls`, bracketed by DECLARATION KIND and by the call sites inside the
# ATTLIST and ELEMENT paths.  See README.md.
#
#   tests/dazzle/sizeprof/run.sh [out-binary] [scalyc-binary]
#     … then run <out-binary> with DZ_SIZEPROF=1.
#
# Sister instrument to ../startbytes (which brackets a dazzle RUN by phase);
# this one brackets an SGML PARSE by declaration kind, because the DTD is the
# largest single memory item of every run — 2.36x the reference, and paid by a
# bare `onsgmls` parse just as much as by a stylesheet run.
#
# It adds one column startbytes does not have: the DOUBLING TRAIL, i.e. every
# bump-hosted Array buffer that growth abandons.  ★Read the survival
# qualification in README.md before believing a trail number: it counts
# GENERATED garbage, not SURVIVING garbage, and only where the region lives to
# program exit (the DTD, the start) are the two the same.
#
# Like startbytes this hooks the ALLOCATOR, so the throwaway build's runtime
# archive comes from the worktree — hence the `rm -f /tmp/libscaly.a` below,
# and do it again afterwards before building anything you intend to measure.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-/tmp/onsgmls-sizeprof}"
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
; --- SIZEPROF probe (throwaway measurement build) -------------------------
function getenv(name: pointer[const_char]) returns pointer[const_char] extern
function calloc(count: size_t, size: size_t) returns pointer[void] extern
procedure atexit(cb: pointer[void]) returns i32 extern

define SP_NBUCKET: i64 19
define SP_NSIZE: i64 1024

shared sp_state: int 0
shared sp_on: bool false
shared sp_cur: i64 0
shared sp_bytes: pointer[i64] null
shared sp_count: pointer[i64] null
shared sp_hist: pointer[i64] null
shared sp_trailc: pointer[i64] null
shared sp_trailb: pointer[i64] null
; ★THE SURVIVAL COLUMN. The bytes column counts REQUESTED bytes, and a bump
; allocation on a frame region is given back by scaly_release_frame — so a big
; number there can be pure churn. `sp_net` is the bucket's NET contribution to
; the live page total, accumulated over every bracket it is entered in. Without
; it this instrument repeats the mistake the doubling-trail counter made.
shared sp_net: pointer[i64] null
shared sp_pagesph: pointer[i64] null
shared sp_livepages: i64 0
shared sp_lastlive: i64 0
shared sp_pages: i64 0
shared sp_relpages: i64 0

function sp_atexit()
    Page.sp_report()

procedure sp_tick(size: size_t)
{
    let k sp_cur
    let b sp_bytes
    let c sp_count
    set *(b + k): *(b + k) + (size as i64)
    set *(c + k): *(c + k) + 1
    if (size as i64) < SP_NSIZE
    {
        let h sp_hist
        let i (k * SP_NSIZE) + (size as i64)
        set *(h + i): *(h + i) + 1
    }
}
'''

REPORT = r'''
    ; --- SIZEPROF probe: the reporting half -------------------------------
    procedure sp_setup()
    {
        set sp_state: 2
        let e getenv("DZ_SIZEPROF")
        if e = null
            return
        set sp_bytes: calloc(SP_NBUCKET as size_t, 8) as pointer[i64]
        set sp_count: calloc(SP_NBUCKET as size_t, 8) as pointer[i64]
        set sp_trailc: calloc(SP_NBUCKET as size_t, 8) as pointer[i64]
        set sp_trailb: calloc(SP_NBUCKET as size_t, 8) as pointer[i64]
        set sp_net: calloc(SP_NBUCKET as size_t, 8) as pointer[i64]
        set sp_pagesph: calloc(SP_NBUCKET as size_t, 8) as pointer[i64]
        set sp_hist: calloc((SP_NBUCKET * SP_NSIZE) as size_t, 8) as pointer[i64]
        if sp_hist = null
            return
        if sp_pagesph = null
            return
        atexit(&sp_atexit)
        set sp_state: 1
        set sp_on: true
    }

    ; the bracket: set the live bucket, hand the old one back, caller restores.
    ; Same technique as startbytes' sb_phase — no global stack, and nesting is
    ; exclusive.
    function sp_bracket(k: i64) returns i64
    {
        if sp_state = 0
            Page.sp_setup()
        ; ★switched off every pointer above is null — return before touching
        ; one. (startbytes shipped for a day with exactly this bug.)
        if sp_on = false
            return 0
        let old sp_cur
        let nt sp_net
        set *(nt + old): *(nt + old) + (sp_livepages - sp_lastlive)
        set sp_lastlive: sp_livepages
        set sp_cur: k
        old
    }

    ; the doubling trail, called from Array.reallocate: a bump-hosted buffer
    ; that growth abandons is region garbage — "there is nothing to release".
    procedure sp_trail(bytes: i64)
    {
        if sp_on = false
            return
        let k sp_cur
        let tc sp_trailc
        let tb sp_trailb
        set *(tc + k): *(tc + k) + 1
        set *(tb + k): *(tb + k) + bytes
    }

    procedure sp_name(k: i64)
    {
        if k = 0
            scaly_eputs "other        "
        if k = 1
            scaly_eputs "element      "
        if k = 2
            scaly_eputs "cm-compile   "
        if k = 3
            scaly_eputs "attlist      "
        if k = 4
            scaly_eputs "decl-value   "
        if k = 5
            scaly_eputs "default-value"
        if k = 6
            scaly_eputs "param        "
        if k = 7
            scaly_eputs "param-in-defv"
        if k = 8
            scaly_eputs "TOKEN-COPY   "
        if k = 9
            scaly_eputs "entity       "
        if k = 10
            scaly_eputs "notation     "
        if k = 11
            scaly_eputs "shortref     "
        if k = 12
            scaly_eputs "usemap       "
        if k = 13
            scaly_eputs "param/gettok "
        if k = 14
            scaly_eputs "param/extend "
        if k = 15
            scaly_eputs "attval-param "
        if k = 16
            scaly_eputs "attval/locs  "
        if k = 17
            scaly_eputs "attval/text  "
        if k = 18
            scaly_eputs "parse-literal"
    }

    procedure sp_report()
    {
        if sp_on = false
            return
        let b sp_bytes
        let c sp_count
        let h sp_hist
        let tc sp_trailc
        let tb sp_trailb
        var tot: i64 0
        var i: i64 0
        while i < SP_NBUCKET
        {
            set tot: tot + *(b + i)
            set i: i + 1
        }
        let nt sp_net
        let pp sp_pagesph
        set *(nt + sp_cur): *(nt + sp_cur) + (sp_livepages - sp_lastlive)
        scaly_eputs "sizeprof: requested "
        scaly_eputi(tot / 1024)
        scaly_eputs " KB total;  pages released "
        scaly_eputi sp_relpages
        scaly_eputs " of "
        scaly_eputi sp_pages
        scaly_eputnl()
        set i: 0
        while i < SP_NBUCKET
        {
            if *(c + i) > 0
            {
                scaly_eputs "  "
                Page.sp_name i
                scaly_eputs "  allocs "
                scaly_eputi(*(c + i))
                scaly_eputs "  requested "
                scaly_eputi(*(b + i) / 1024)
                scaly_eputs " KB   trail "
                scaly_eputi(*(tc + i))
                scaly_eputs " buffers / "
                scaly_eputi(*(tb + i) / 1024)
                scaly_eputs " KB   NET LIVE "
                scaly_eputi(*(nt + i) * (PAGE_SIZE as i64) / 1024)
                scaly_eputs " KB"
                scaly_eputnl()
                var shown: i64 0
                var cut: i64 0
                while shown < 10
                {
                    var best: i64 (0 - 1)
                    var bestv: i64 0
                    var s: i64 0
                    while s < SP_NSIZE
                    {
                        let v *(h + (i * SP_NSIZE) + s) * s
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
                        set shown: 10
                    if best >= 0
                    {
                        scaly_eputs "      size "
                        scaly_eputi best
                        scaly_eputs " x "
                        scaly_eputi(*(h + (i * SP_NSIZE) + best))
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
     "        if sp_state = 0\n            Page.sp_setup()\n"
     "        if sp_on\n            sp_tick(size)\n"
     "        let location next_object as size_t"),
    ("        let page_addr (b as size_t) + ((slot + 1) as size_t) * PAGE_SIZE\n        let page page_addr as pointer[Page]",
     "        if sp_on\n        {\n            set sp_pages: sp_pages + 1\n"
     "            set sp_livepages: sp_livepages + 1\n"
     "            let pp sp_pagesph\n            set *(pp + sp_cur): *(pp + sp_cur) + 1\n        }\n"
     "        let page_addr (b as size_t) + ((slot + 1) as size_t) * PAGE_SIZE\n        let page page_addr as pointer[Page]"),
    ("    function release_page(p: pointer[Page])\n    {",
     "    function release_page(p: pointer[Page])\n    {\n"
     "        if sp_on\n        {\n"
     "            ; an oversized block is not a HeapBucket page and was never counted\n"
     "            if p.next_object <> null\n            {\n"
     "                set sp_livepages: sp_livepages - 1\n                set sp_relpages: sp_relpages + 1\n            }\n        }"),
    ("    ; Attributed variants of allocate_page/release_page for the",
     REPORT + "\n    ; Attributed variants of allocate_page/release_page for the"),
])

# ---- the doubling trail: the "still small" branch of Array.reallocate is the
# one that abandons a bump-hosted buffer (the big branch releases a page).
patch('/packages/scaly/0.1.0/scaly/containers/Array.scaly', [
    ("            let new_vector Vector[T]^own_page(new_capacity)\n            memcpy(new_vector.data, vector.data, vector.length * size)",
     "            Page.sp_trail((vector.length * size) as i64)\n"
     "            let new_vector Vector[T]^own_page(new_capacity)\n            memcpy(new_vector.data, vector.data, vector.length * size)"),
])

# ---------------------------------------------------------- the brackets ---
patch('/packages/opensp/0.1.0/opensp/Parser.scaly', [
    # --- per declaration kind, at the one dispatcher in parse_declaration ---
    ("                            set result: this.parse_element_decl()",
     "                        {\n                            let sp_e Page.sp_bracket(1)\n"
     "                            set result: this.parse_element_decl()\n"
     "                            Page.sp_bracket(sp_e)\n                        }"),
    ("                    else if decl_name = R_ATTLIST\n                        set result: this.parse_attlist_decl()",
     "                    else if decl_name = R_ATTLIST\n                    {\n"
     "                        let sp_a Page.sp_bracket(3)\n                        set result: this.parse_attlist_decl()\n"
     "                        Page.sp_bracket(sp_a)\n                    }"),
    ("                    else if decl_name = R_ENTITY\n                        set result: this.parse_entity_decl(mdo_loc)",
     "                    else if decl_name = R_ENTITY\n                    {\n"
     "                        let sp_en Page.sp_bracket(9)\n                        set result: this.parse_entity_decl(mdo_loc)\n"
     "                        Page.sp_bracket(sp_en)\n                    }"),
    ("                        set result: this.parse_notation_decl()\n",
     "                        let sp_no Page.sp_bracket(10)\n"
     "                        set result: this.parse_notation_decl()\n"
     "                        Page.sp_bracket(sp_no)\n"),
    ("                            set result: this.parse_shortref_decl(mdo_loc)",
     "                        {\n                            let sp_sr Page.sp_bracket(11)\n"
     "                            set result: this.parse_shortref_decl(mdo_loc)\n"
     "                            Page.sp_bracket(sp_sr)\n                        }"),
    ("                            set result: this.parse_usemap_decl()",
     "                        {\n                            let sp_um Page.sp_bracket(12)\n"
     "                            set result: this.parse_usemap_decl()\n"
     "                            Page.sp_bracket(sp_um)\n                        }"),
    # --- the content-model DFA, 21.6 MB at one call site --------------------
    ("            let compiled ContentToken.compile(host, parm.model_group, dtd.n_element_type_index(), ambiguities, &pcdata_unreachable)",
     "            let sp_cm Page.sp_bracket(2)\n"
     "            let compiled ContentToken.compile(host, parm.model_group, dtd.n_element_type_index(), ambiguities, &pcdata_unreachable)\n"
     "            Page.sp_bracket(sp_cm)"),
    # --- the workhorse. A function with many returns gets a WRAPPER.
    # `param-in-defv` is a separate bucket because parse_default_value's own
    # parameter scan is where 592 688 of the allocations sit.
    ("    function parse_param(this: Parser, allow: pointer[AllowedParams], decl_input_level: u32, parm: pointer[Param]) returns bool\n    {\n        var looping true",
     "    function parse_param(this: Parser, allow: pointer[AllowedParams], decl_input_level: u32, parm: pointer[Param]) returns bool\n    {\n"
     "        let sp_outer Page.sp_bracket(6)\n"
     "        if sp_outer = 5\n            Page.sp_bracket(7)\n"
     "        let r this.parse_param_inner(allow, decl_input_level, parm)\n"
     "        Page.sp_bracket(sp_outer)\n        r\n    }\n\n"
     "    function parse_param_inner(this: Parser, allow: pointer[AllowedParams], decl_input_level: u32, parm: pointer[Param]) returns bool\n    {\n        var looping true"),
    # --- the two sub-brackets that decide WHERE parse_param's bytes are -----
    ("            let token ps.get_token(allow.main_mode)",
     "            let sp_gt Page.sp_bracket(13)\n            let token ps.get_token(allow.main_mode)\n            Page.sp_bracket(sp_gt)"),
    ("                    this.extend_name_token(this.namelen(), ParserMessages.nameLength())\n                    set parm.kind: P_NAME",
     "                    let sp_x1 Page.sp_bracket(14)\n"
     "                    this.extend_name_token(this.namelen(), ParserMessages.nameLength())\n"
     "                    Page.sp_bracket(sp_x1)\n                    set parm.kind: P_NAME"),
    ("                    this.extend_name_token(this.namelen(), ParserMessages.nameLength())\n                    set parm.kind: P_ENTITYNAME",
     "                    let sp_x2 Page.sp_bracket(14)\n"
     "                    this.extend_name_token(this.namelen(), ParserMessages.nameLength())\n"
     "                    Page.sp_bracket(sp_x2)\n                    set parm.kind: P_ENTITYNAME"),
    # --- parse_literal: the literal arm of parse_param. ★Its per-char
    # Location spur was measured 2026-08-02 and hosted on the TEXT's page;
    # this bracket says what it still costs where that page is the run page.
    ("    function parse_literal(this: Parser, lit_mode: int, single_space: bool, data_tag: bool, max_length: size_t, too_long: MessageType, out_text: pointer[Text]) returns bool\n    {",
     "    function parse_literal(this: Parser, lit_mode: int, single_space: bool, data_tag: bool, max_length: size_t, too_long: MessageType, out_text: pointer[Text]) returns bool\n    {\n"
     "        let sp_pl Page.sp_bracket(18)\n        let rpl this.parse_literal_inner(lit_mode, single_space, data_tag, max_length, too_long, out_text)\n"
     "        Page.sp_bracket(sp_pl)\n        return rpl\n    }\n\n"
     "    function parse_literal_inner(this: Parser, lit_mode: int, single_space: bool, data_tag: bool, max_length: size_t, too_long: MessageType, out_text: pointer[Text]) returns bool\n    {"),
    # --- parse_attribute_value_param: the DEFAULT-VALUE workhorse, and the
    # per-character Location table inside it (the reference stores ONE
    # TextItem for the whole value — Text::addChars).
    ("    function parse_attribute_value_param(this: Parser, parm: pointer[Param]) returns bool\n    {\n        this.extend_name_token(",
     "    function parse_attribute_value_param(this: Parser, parm: pointer[Param]) returns bool\n    {\n"
     "        let sp_av Page.sp_bracket(15)\n        let rav this.parse_attribute_value_param_inner(parm)\n"
     "        Page.sp_bracket(sp_av)\n        return rav\n    }\n\n"
     "    function parse_attribute_value_param_inner(this: Parser, parm: pointer[Param]) returns bool\n    {\n        this.extend_name_token("),
    ("        let tlb host.allocate(tn * sizeof Location, alignof Location) as pointer[Location]",
     "        let sp_lo Page.sp_bracket(16)\n        let tlb host.allocate(tn * sizeof Location, alignof Location) as pointer[Location]\n        Page.sp_bracket(sp_lo)"),
    ("        let txt host.allocate(sizeof Text, alignof Text) as pointer[Text]\n        ; per-char locations (linear: the value is one source token) — the",
     "        let sp_tx Page.sp_bracket(17)\n        let txt host.allocate(sizeof Text, alignof Text) as pointer[Text]\n        Page.sp_bracket(sp_tx)\n        ; per-char locations (linear: the value is one source token) — the"),
    ("                    this.extend_name_token(this.penamelen(), ParserMessages.parameterEntityNameLength())\n                    set parm.kind: P_PARAMENTITYNAME",
     "                    let sp_x3 Page.sp_bracket(14)\n"
     "                    this.extend_name_token(this.penamelen(), ParserMessages.parameterEntityNameLength())\n"
     "                    Page.sp_bracket(sp_x3)\n                    set parm.kind: P_PARAMENTITYNAME"),
    # --- ★the four token copies: the item this instrument was rebuilt for.
    # Their sum IS the ceiling of the ATTLIST lifetime seam.
    ("                    set parm.orig_token: ps.current_token^host()\n                    set parm.token: this.name_folded^host()",
     "                    let sp_t1 Page.sp_bracket(8)\n"
     "                    set parm.orig_token: ps.current_token^host()\n"
     "                    set parm.token: this.name_folded^host()\n"
     "                    Page.sp_bracket(sp_t1)"),
    ("                    set parm.kind: P_ENTITYNAME\n                    ; NAMECASE ENTITY NO: entity names stay case-exact (unlike\n                    ; P_NAME above, which folds under NAMECASE GENERAL YES).\n                    set parm.token: ps.current_token^host()",
     "                    set parm.kind: P_ENTITYNAME\n                    let sp_t2 Page.sp_bracket(8)\n"
     "                    set parm.token: ps.current_token^host()\n                    Page.sp_bracket(sp_t2)"),
    ("                    set parm.kind: P_PARAMENTITYNAME\n                    ; NAMECASE ENTITY NO: parameter-entity names stay case-exact.\n                    set parm.token: ps.current_token^host()",
     "                    set parm.kind: P_PARAMENTITYNAME\n                    let sp_t3 Page.sp_bracket(8)\n"
     "                    set parm.token: ps.current_token^host()\n                    Page.sp_bracket(sp_t3)"),
    ("                    set parm.kind: P_NUMBER\n                    set parm.token: ps.current_token^host()",
     "                    set parm.kind: P_NUMBER\n                    let sp_t4 Page.sp_bracket(8)\n"
     "                    set parm.token: ps.current_token^host()\n                    Page.sp_bracket(sp_t4)"),
    # --- the two ATTLIST internals, both wrappers (many returns) ------------
    ("    function parse_declared_value(this: Parser, decl_input_level: u32, is_notation: bool, parm: pointer[Param], out_allowed_flags: pointer[int]) returns pointer[DeclaredValue]\n    {",
     "    function parse_declared_value(this: Parser, decl_input_level: u32, is_notation: bool, parm: pointer[Param], out_allowed_flags: pointer[int]) returns pointer[DeclaredValue]\n    {\n"
     "        let sp_dv Page.sp_bracket(4)\n"
     "        let rdv this.parse_declared_value_inner(decl_input_level, is_notation, parm, out_allowed_flags)\n"
     "        Page.sp_bracket(sp_dv)\n        return rdv\n    }\n\n"
     "    function parse_declared_value_inner(this: Parser, decl_input_level: u32, is_notation: bool, parm: pointer[Param], out_allowed_flags: pointer[int]) returns pointer[DeclaredValue]\n    {"),
    ("    function parse_default_value(this: Parser, decl_input_level: u32, is_notation: bool, parm: pointer[Param], attribute_name: StringC, declared_value: pointer[DeclaredValue], out_def: pointer[pointer[AttributeDefinition]], any_current: pointer[bool]) returns bool\n    {",
     "    function parse_default_value(this: Parser, decl_input_level: u32, is_notation: bool, parm: pointer[Param], attribute_name: StringC, declared_value: pointer[DeclaredValue], out_def: pointer[pointer[AttributeDefinition]], any_current: pointer[bool]) returns bool\n    {\n"
     "        let sp_dfv Page.sp_bracket(5)\n"
     "        let rdfv this.parse_default_value_inner(decl_input_level, is_notation, parm, attribute_name, declared_value, out_def, any_current)\n"
     "        Page.sp_bracket(sp_dfv)\n        return rdfv\n    }\n\n"
     "    function parse_default_value_inner(this: Parser, decl_input_level: u32, is_notation: bool, parm: pointer[Param], attribute_name: StringC, declared_value: pointer[DeclaredValue], out_def: pointer[pointer[AttributeDefinition]], any_current: pointer[bool]) returns bool\n    {"),
])
PY

TMP="$(mktemp -d)"
cd "$WT"
rm -f /tmp/libscaly.a /tmp/libscaly.ll
if ! tests/sgml/build-onsgmls.sh "$OUT" "$BIN" > "$TMP/build.log" 2>&1; then
  echo "FAIL (build)"; tail -30 "$TMP/build.log"; rm -rf "$TMP"; exit 1
fi
rm -rf "$TMP"
echo "sizeprof: built $OUT  (run with DZ_SIZEPROF=1)"
