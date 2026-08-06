#!/usr/bin/env python3
"""tests/dazzle/nsweep/sweep.py — the complexity screen.

Driven by run.sh; see README.md for what it is and what it found. Everything
here is black-box: it writes documents and stylesheets, runs two engines over
them, and reads the counters back out of /usr/bin/time. No engine source is
touched, so this instrument cannot rot against an internal rename.
"""

import argparse
import os
import re
import subprocess
import sys

# The document: ONE parent holding N children, because the sibling group is the
# axis every candidate walks. `mix` alternates two GIs — that matters, because a
# primitive that short-circuits on the FIRST same-GI sibling looks linear on a
# uniform group and quadratic on a mixed one (first-sibling? is exactly that).
DOC_HEAD = """<!DOCTYPE doc [
<!ELEMENT doc - - (sect*)>
<!ELEMENT sect - - ((item|note)*)>
<!ELEMENT item - - (#PCDATA)>
<!ELEMENT note - - (#PCDATA)>
<!ATTLIST item id ID #IMPLIED  kind CDATA #IMPLIED>
<!ATTLIST note id ID #IMPLIED>
]>
<doc>
<sect>
"""

SHEET = """<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
(root (make sequence (process-children)))
(element doc (process-children))
(element sect (process-children))
(element note (literal "."))
(element item (literal %s))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
"""

# name, probe expression. The three CONTROLS are not decoration: `element-number`
# proves the NumberCache port still works, and `node-list-length (children)` is
# the GUARDRAIL — the one row where the work is genuinely required, and where
# the port is an order of magnitude ahead of the reference. A change that fixes
# the rows above it and spoils that one has not helped.
PROBES = [
    ("child-number",              '(number->string (child-number))'),
    ("first-sibling?",            '(if (first-sibling?) "1" "0")'),
    ("last-sibling?",             '(if (last-sibling?) "1" "0")'),
    ("absolute-first-sibling?",   '(if (absolute-first-sibling?) "1" "0")'),
    ("absolute-last-sibling?",    '(if (absolute-last-sibling?) "1" "0")'),
    ("node-list-first children",  '(gi (node-list-first (children (parent))))'),
    ("node-list-ref children 3",  '(number->string (node-list-length (node-list-ref (children (parent)) 3)))'),
    ("node-list-empty? descend",  '(if (node-list-empty? (descendants (parent))) "1" "0")'),
    ("node-list-first preced",    '(if (node-list-empty? (preced (current-node))) "e" (gi (node-list-first (preced (current-node)))))'),
    ("node-list-first follow",    '(if (node-list-empty? (follow (current-node))) "e" (gi (node-list-first (follow (current-node)))))'),
    ("select-elements length",    '(number->string (node-list-length (select-elements (children (parent)) "item")))'),
    ("node-list-length children", '(number->string (node-list-length (children (parent))))'),
    ("element-number [control]",  '(number->string (element-number))'),
    ("attribute-string [control]", '(or (attribute-string "kind") "n")'),
    ("element-with-id [control]", '(if (node-list-empty? (element-with-id "i1")) "0" "1")'),
    ("ancestor [control]",        '(number->string (node-list-length (ancestor "doc")))'),
]

BASELINE = '"x"'


def write_doc(path, n, mixed):
    parts = [DOC_HEAD]
    for i in range(n):
        if mixed and i % 2:
            parts.append('<note>n%d</note>\n' % i)
        else:
            parts.append('<item id="i%d" kind="k">t%d</item>\n' % (i, i))
    parts.append("</sect>\n</doc>\n")
    open(path, "w").write("".join(parts))


def measure(engine, flags, sheet_path, doc_path, home):
    """-> (cost, unit, error). Instructions where the OS reports them, else cpu."""
    env = dict(os.environ)
    if home:
        env["SCALY_HOME"] = home
    try:
        r = subprocess.run(["/usr/bin/time", "-l", engine] + flags +
                           ["-d", sheet_path, doc_path],
                           capture_output=True, text=True, env=env)
    except OSError as e:
        return None, None, str(e)
    err = r.stderr
    bad = [l for l in err.split("\n") if ":E:" in l]
    if bad:
        return None, None, bad[0][:90]
    # ★An engine that did not RUN must fail loudly. `/usr/bin/time -l` prints a
    # resource block even when the exec fails, so a mistyped REF_JADE otherwise
    # yields a near-zero baseline, a near-zero probe, and the instrument reports
    # "the reference does not pay it" — its strongest verdict — about a program
    # that never started. A checker that cannot fail is worse than none.
    if r.returncode != 0:
        return None, None, "exit %d: %s" % (r.returncode, err.strip().split("\n")[0][:70])
    if not r.stdout.strip():
        return None, None, "produced no output (did the engine run?)"
    m = re.search(r"(\d+)\s+instructions retired", err)
    if m:
        return int(m.group(1)), "instr", None
    # Linux `/usr/bin/time -l` is not a thing; run.sh passes -v there and the
    # counter does not exist at all, so fall back to cpu seconds and say so.
    m = re.search(r"([\d.]+)\s+real\s+([\d.]+)\s+user\s+([\d.]+)\s+sys", err)
    if m:
        return (float(m.group(2)) + float(m.group(3))) * 1e6, "us", None
    m = re.search(r"User time \(seconds\): ([\d.]+)", err)
    m2 = re.search(r"System time \(seconds\): ([\d.]+)", err)
    if m and m2:
        return (float(m.group(1)) + float(m2.group(1))) * 1e6, "us", None
    return None, None, "no counter in /usr/bin/time output"


def slope(marg, floor):
    """Growth of the MARGINAL cost per doubling. 2 = linear, 4 = quadratic."""
    if len(marg) < 2 or marg[-2] < floor:
        return None
    return marg[-1] / marg[-2]


def median3(fn):
    """The BASELINE is measured three times and the middle one kept.

    ★Not decoration: a probe whose own cost is under a per cent of the run
    disappears into the baseline's run-to-run spread, and the marginal comes out
    NEGATIVE. That is exactly the reference's situation on every row the port is
    quadratic in — and read naively it says "the reference is quadratic too",
    i.e. the instrument reports the OPPOSITE of the finding. The probes
    themselves are not repeated: where the answer matters the marginal is
    hundreds of times the noise.
    """
    xs = []
    for _ in range(3):
        v, u, e = fn()
        if v is None:
            return None, None, e
        xs.append((v, u))
    xs.sort(key=lambda t: t[0])
    return xs[1][0], xs[1][1], None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True)
    ap.add_argument("--ref", default="")
    ap.add_argument("--home", default="")
    ap.add_argument("--workdir", required=True)
    ap.add_argument("--sizes", default="500 1000 2000 4000")
    ap.add_argument("--filter", default="")
    ap.add_argument("--mixed", action="store_true")
    a = ap.parse_args()

    ns = [int(x) for x in a.sizes.split()]
    fam = "mix" if a.mixed else "doc"
    docs = {}
    for n in ns:
        p = os.path.join(a.workdir, "%s%d.sgml" % (fam, n))
        write_doc(p, n, a.mixed)
        docs[n] = p
    sheet = os.path.join(a.workdir, "p.dsl")

    engines = [("port", a.port, ["-t", "sgml"], a.home)]
    if a.ref:
        engines.append(("ref", a.ref, ["-G", "-t", "sgml"], ""))

    unit = None
    base = {}
    for tag, exe, flags, home in engines:
        open(sheet, "w").write(SHEET % BASELINE)
        row = []
        for n in ns:
            v, u, e = median3(lambda: measure(exe, flags, sheet, docs[n], home))
            if v is None:
                print("nsweep: baseline failed for %s: %s" % (tag, e))
                return 2
            unit = unit or u
            row.append(v)
        base[tag] = row

    scale = 1e6 if unit == "instr" else 1e3
    suffix = "M" if unit == "instr" else "ms"
    # everything under this is baseline spread, not signal
    floor = 2.0 if unit == "instr" else 20.0
    print("  document: ONE parent, N children (%s)   sizes: %s   unit: %s" %
          ("two GIs alternating" if a.mixed else "one GI",
           ", ".join(str(n) for n in ns),
           "instructions" if unit == "instr" else "cpu (NO instruction counter here — noisier)"))
    head = "  %-28s %12s %7s" % ("probe", "port@max", "x/2x")
    if a.ref:
        head += " %12s %7s   verdict" % ("ref@max", "x/2x")
    else:
        head += "   verdict (no reference — cannot tell a defect from inherent cost)"
    print(head)

    rc = 0
    for name, expr in PROBES:
        if a.filter and a.filter not in name:
            continue
        marg = {}
        failed = None
        for tag, exe, flags, home in engines:
            open(sheet, "w").write(SHEET % expr)
            vals = []
            for i, n in enumerate(ns):
                v, _, e = measure(exe, flags, sheet, docs[n], home)
                if v is None:
                    failed = "%s: %s" % (tag, e)
                    break
                # clamped: a marginal below the baseline's own spread is not a
                # negative cost, it is "too cheap to see"
                vals.append(max(0.0, (v - base[tag][i]) / scale))
            if failed:
                break
            marg[tag] = vals
        if failed:
            print("  %-28s SKIP  %s" % (name, failed))
            continue
        ps = slope(marg["port"], floor)
        line = "  %-28s %11.1f%s %7s" % (
            name, marg["port"][-1], suffix, "  -  " if ps is None else "%5.2f" % ps)
        if a.ref:
            rs = slope(marg["ref"], floor)
            line += " %11.1f%s %7s   " % (
                marg["ref"][-1], suffix, "  -  " if rs is None else "%5.2f" % rs)
            # ★The order of these tests is the whole instrument. A reference
            # marginal UNDER the floor means the reference does not pay this at
            # all — which is the strongest form of "port defect", not a missing
            # measurement. Reading a missing reference slope as "quadratic too"
            # inverted six of nine verdicts in the first draft.
            if ps is None:
                verdict = "below the noise floor"
            elif marg["ref"][-1] < max(floor, marg["port"][-1] * 0.05):
                verdict = "*** PORT DEFECT *** (the reference does not pay it)"
                rc = 1
            elif rs is not None and rs > 3.0:
                verdict = "inherent (the reference is quadratic too)"
            elif ps > 3.0:
                verdict = "*** PORT DEFECT ***"
                rc = 1
            else:
                verdict = "linear"
            if marg["port"][-1] * 3 < marg["ref"][-1]:
                verdict += "  [port %.0fx cheaper]" % (marg["ref"][-1] / max(marg["port"][-1], 1e-9))
            line += verdict
        else:
            line += "   " + ("quadratic" if ps and ps > 3.0 else "linear" if ps else "-")
        print(line)
    return rc


if __name__ == "__main__":
    sys.exit(main())
