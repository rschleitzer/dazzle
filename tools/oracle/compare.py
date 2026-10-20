#!/usr/bin/env python3
"""tools/oracle/compare.py -- this port's PDF backend held against Dazzle.Pdf.

  tools/oracle/compare.py [--fonts DIR] [--tolerance PT] [--keep DIR] doc.xml style.dsl...

Sets each document with both -- the port (`dazzle -t pdf`, the binary in
$DAZZLE, else scalyc/build/dazzle of a Scaly checkout beside this one) and
Dazzle.Pdf (tools/oracle, built on first use with dotnet) -- with the same
font files (--fonts, default the system's supplemental fonts on macOS), and
compares what both pages show: every word with its box (pdftotext -bbox),
page by page and in reading order, the pages' sizes, and what is drawn --
every stroked line with its thickness and every filled rectangle (scores,
rules, borders, backgrounds) and where each image stands, read from the
content streams with pypdf, and
where every element with an ID begins (the port's --locations against
GeneratePdfWithLocations). A word that differs, or stands more than the
tolerance (default 0.5 pt) away from its place in the other, is reported; the
exit status is 1 when anything is.

The oracle is the C# backend this port's layout was taken over by, and has
grown beyond since (min-leading, score, tabs, row spans, column sets, page
models). Where both agree within the tolerance, a port step is done.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from html import unescape

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def words(pdf):
    """[(page width, height, [(text, xmin, ymin, xmax, ymax)])] per page."""
    out = subprocess.run(["pdftotext", "-bbox", pdf, "-"], capture_output=True, text=True, check=True).stdout
    pages = []
    for page in re.finditer(r'<page width="([\d.]+)" height="([\d.]+)">(.*?)</page>', out, re.S):
        ws = [(unescape(m.group(5)), float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4)))
              for m in re.finditer(r'<word xMin="([\d.-]+)" yMin="([\d.-]+)" xMax="([\d.-]+)" yMax="([\d.-]+)">(.*?)</word>', page.group(3))]
        pages.append((float(page.group(1)), float(page.group(2)), ws))
    return pages


def graphics(pdf):
    """[([lines (x1, y1, x2, y2, width, dash, phase)], [rectangles (x, y, w, h)], [images
    (x, y, w, h)])] per page, in points from the top left: what the content
    stream strokes and fills, and where it draws an XObject (the unit square
    under the current matrix). A line's dash is the length of its pattern (an
    odd one taken twice, as it repeats), 0 for a solid line."""
    from pypdf import PdfReader
    pages = []
    for page in PdfReader(pdf).pages:
        height = float(page.mediabox.height)
        # (a content stream is a dictionary: an empty one is false, so ask for None)
        contents = page.get_contents()
        ops = contents.operations if contents is not None else []
        ctm = [1, 0, 0, 1, 0, 0]
        stack, width, path, lines, rects, images = [], 1.0, [], [], [], []
        dash, phase = 0.0, 0.0

        def mul(m, n):
            return [m[0] * n[0] + m[1] * n[2], m[0] * n[1] + m[1] * n[3],
                    m[2] * n[0] + m[3] * n[2], m[2] * n[1] + m[3] * n[3],
                    m[4] * n[0] + m[5] * n[2] + n[4], m[4] * n[1] + m[5] * n[3] + n[5]]

        def at(x, y):
            return (ctm[0] * x + ctm[2] * y + ctm[4], height - (ctm[1] * x + ctm[3] * y + ctm[5]))

        for operands, op in ops:
            op = op.decode() if isinstance(op, bytes) else op
            v = [float(o) for o in operands if isinstance(o, (int, float)) or hasattr(o, "as_numeric")]
            if op == "q":
                stack.append((ctm, width, dash, phase))
            elif op == "Q" and stack:
                ctm, width, dash, phase = stack.pop()
            elif op == "d" and len(operands) == 2:
                pattern = [float(v) for v in operands[0]]
                if len(pattern) % 2 == 1:
                    pattern = pattern * 2
                dash, phase = sum(pattern), float(operands[1])
            elif op == "cm" and len(v) == 6:
                ctm = mul(v, ctm)
            elif op == "w" and v:
                width = v[0] * abs(ctm[3] or ctm[0] or 1)
            elif op == "m" and len(v) == 2:
                path.append(("m", at(*v)))
            elif op == "l" and len(v) == 2:
                path.append(("l", at(*v)))
            elif op == "re" and len(v) == 4:
                a, b = at(v[0], v[1]), at(v[0] + v[2], v[1] + v[3])
                path.append(("re", (min(a[0], b[0]), min(a[1], b[1]), abs(b[0] - a[0]), abs(b[1] - a[1]))))
            elif op == "Do":
                # an image is the unit square; a form its BBox under its Matrix
                x0, y0, x1, y1, m = 0.0, 0.0, 1.0, 1.0, [1, 0, 0, 1, 0, 0]
                try:
                    xobj = page["/Resources"]["/XObject"][operands[0]].get_object()
                    if xobj.get("/Subtype") == "/Form":
                        x0, y0, x1, y1 = [float(v) for v in xobj["/BBox"]]
                        m = [float(v) for v in xobj.get("/Matrix", m)]
                except (KeyError, TypeError):
                    pass
                pts = []
                for px, py in ((x0, y0), (x1, y1), (x0, y1), (x1, y0)):
                    pts.append(at(m[0] * px + m[2] * py + m[4], m[1] * px + m[3] * py + m[5]))
                xs, ys = [p[0] for p in pts], [p[1] for p in pts]
                images.append((min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)))
            elif op in ("S", "s", "f", "F", "f*", "B", "B*", "b", "b*", "n"):
                prev = None
                for kind, pt in path:
                    if kind == "m":
                        prev = pt
                    elif kind == "l" and prev is not None and op in ("S", "s", "B", "B*", "b", "b*"):
                        lines.append((prev[0], prev[1], pt[0], pt[1], width, dash, phase))
                        prev = pt
                    elif kind == "re" and op in ("f", "F", "f*", "B", "B*", "b", "b*"):
                        rects.append(pt)
                path = []
        pages.append((lines, rects, images))
    return pages


def same_lines(wa, wb, tolerance):
    """Whether two pages show the same lines -- the same text from the same
    start to the same end at the same height -- where they are split into
    words differently: a run drawn character by character (letter-spacing in
    Dazzle.Pdf) reads as single letters, one drawn with a character spacing
    (Tc, the port) as one word."""
    def lines(ws):
        out = []
        for w in sorted(ws, key=lambda w: (round(w[4] * 2) / 2, w[1])):
            if out and abs(out[-1][3] - w[4]) <= tolerance:
                text, x0, x1, y = out[-1]
                out[-1] = (text + w[0], x0, max(x1, w[3]), y)
            else:
                out.append((w[0], w[1], w[3], w[4]))
        return out
    la, lb = lines(wa), lines(wb)
    return len(la) == len(lb) and all(
        a[0] == b[0] and all(abs(p - q) <= tolerance for p, q in zip(a[1:], b[1:])) for a, b in zip(la, lb))


def match(port, oracle, tolerance):
    """The items of one list that have no partner within the tolerance in
    the other: (port only, oracle only)."""
    left = list(oracle)
    alone = []
    for item in port:
        for j, other in enumerate(left):
            if all(abs(a - b) <= tolerance for a, b in zip(item, other)):
                del left[j]
                break
        else:
            alone.append(item)
    return alone, left


def oracle_binary(keep):
    built = os.path.join(keep, "oracle-bin", "Oracle.dll")
    if not os.path.exists(built):
        # ORACLE_FEED: a directory of packages to take Dazzle.Pdf from before
        # nuget.org has it (`dotnet pack src/pdf -o <dir>` in dazzle-net)
        feed = ["--source", os.environ["ORACLE_FEED"], "--source", "https://api.nuget.org/v3/index.json"] \
            if os.environ.get("ORACLE_FEED") else []
        subprocess.run(["dotnet", "build", HERE, "-o", os.path.dirname(built), "-v", "q"] + feed, check=True,
                       stdout=subprocess.DEVNULL)
    return built


def port_binary():
    if os.environ.get("DAZZLE"):
        return os.environ["DAZZLE"]
    return os.path.join(ROOT, "..", "Scaly", "scalyc", "build", "dazzle")


def compare(doc, dsl, fonts, tolerance, work, oracle):
    name = os.path.splitext(os.path.basename(doc))[0]
    port_pdf = os.path.join(work, name + ".port.pdf")
    oracle_pdf = os.path.join(work, name + ".oracle.pdf")
    port_json = os.path.join(work, name + ".port.json")
    oracle_json = os.path.join(work, name + ".oracle.json")
    env = dict(os.environ, DAZZLE_FONTS=fonts, SP_CHARSET_FIXED="YES", SP_ENCODING="XML")
    # an XML document is read after the SGML declaration of XML, as onsgmls
    # reads one; Dazzle.Pdf has it built in
    xml_dcl = os.path.join(ROOT, "upstream", "pubtext", "xml.dcl")
    p = subprocess.run([port_binary(), "-t", "pdf", "-o", port_pdf, "--locations", port_json, "-d", dsl, xml_dcl, doc], env=env,
                       capture_output=True, text=True)
    if p.returncode != 0 or p.stderr.strip():
        return ["port: rc=%d %s" % (p.returncode, p.stderr.strip()[:400])]
    o = subprocess.run(["dotnet", oracle, doc, dsl, oracle_pdf, oracle_json, fonts],
                       capture_output=True, text=True)
    if o.returncode != 0:
        return ["oracle: rc=%d %s" % (o.returncode, o.stderr.strip()[:400])]
    a, b = words(port_pdf), words(oracle_pdf)
    findings = []
    if len(a) != len(b):
        findings.append("pages: port %d, oracle %d" % (len(a), len(b)))
    for n, (pa, pb) in enumerate(zip(a, b), 1):
        if abs(pa[0] - pb[0]) > tolerance or abs(pa[1] - pb[1]) > tolerance:
            findings.append("page %d: size port %.1fx%.1f, oracle %.1fx%.1f" % (n, pa[0], pa[1], pb[0], pb[1]))
        wa, wb = pa[2], pb[2]
        if [w[0] for w in wa] != [w[0] for w in wb] and same_lines(wa, wb, tolerance):
            continue
        for i, (x, y) in enumerate(zip(wa, wb)):
            if x[0] != y[0]:
                findings.append("page %d word %d: port %r at %.1f,%.1f, oracle %r at %.1f,%.1f"
                                % (n, i, x[0], x[1], x[4], y[0], y[1], y[4]))
                break
            dx, dy = x[1] - y[1], x[4] - y[4]
            if abs(dx) > tolerance or abs(dy) > tolerance:
                findings.append("page %d word %d %r: port %.2f,%.2f, oracle %.2f,%.2f (dx %+.2f, dy %+.2f)"
                                % (n, i, x[0], x[1], x[4], y[1], y[4], dx, dy))
        if len(wa) != len(wb):
            findings.append("page %d: words port %d, oracle %d" % (n, len(wa), len(wb)))
    with open(port_json) as f:
        la = json.load(f)
    with open(oracle_json) as f:
        lb = json.load(f)
    for key in sorted(set(la) | set(lb)):
        if key not in la or key not in lb:
            findings.append("location %s: only in the %s" % (key, "oracle" if key not in la else "port"))
        elif la[key][0] != lb[key][0] or any(abs(a - b) > tolerance for a, b in zip(la[key][1:], lb[key][1:])):
            findings.append("location %s: port page %d at %.2f,%.2f, oracle page %d at %.2f,%.2f"
                            % (key, la[key][0], la[key][1], la[key][2], lb[key][0], lb[key][1], lb[key][2]))
    try:
        ga, gb = graphics(port_pdf), graphics(oracle_pdf)
    except ImportError:
        return findings + ["graphics not compared: no pypdf"]
    for n, ((la, ra, ia), (lb, rb, ib)) in enumerate(zip(ga, gb), 1):
        for what, mine, theirs in (("line", la, lb), ("rectangle", ra, rb), ("image", ia, ib)):
            only_port, only_oracle = match(mine, theirs, tolerance)
            for item in only_port:
                findings.append("page %d: %s only in the port: %s" % (n, what, ", ".join("%.2f" % v for v in item)))
            for item in only_oracle:
                findings.append("page %d: %s only in the oracle: %s" % (n, what, ", ".join("%.2f" % v for v in item)))
    return findings


def main():
    args = sys.argv[1:]
    fonts = "/System/Library/Fonts/Supplemental"
    tolerance = 0.5
    keep = None
    while args and args[0].startswith("--"):
        flag = args.pop(0)
        if flag == "--fonts":
            fonts = args.pop(0)
        elif flag == "--tolerance":
            tolerance = float(args.pop(0))
        elif flag == "--keep":
            keep = args.pop(0)
        else:
            sys.exit("compare.py: unknown flag " + flag)
    if len(args) < 2 or len(args) % 2:
        sys.exit(__doc__)
    work = keep or tempfile.mkdtemp()
    os.makedirs(work, exist_ok=True)
    oracle = oracle_binary(work)
    failed = 0
    for doc, dsl in zip(args[0::2], args[1::2]):
        findings = compare(doc, dsl, fonts, tolerance, work, oracle)
        name = os.path.basename(doc)
        if findings:
            failed += 1
            print("%s: %d finding%s" % (name, len(findings), "" if len(findings) == 1 else "s"))
            for f in findings[:40]:
                print("  " + f)
            if len(findings) > 40:
                print("  ... %d more" % (len(findings) - 40))
        else:
            print("%s: the same within %.2f pt" % (name, tolerance))
    if keep is None:
        shutil.rmtree(work, ignore_errors=True)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
