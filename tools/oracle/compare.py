#!/usr/bin/env python3
"""tools/oracle/compare.py -- this port's PDF backend held against Dazzle.Pdf.

  tools/oracle/compare.py [--fonts DIR] [--tolerance PT] [--keep DIR] doc.xml style.dsl...

Sets each document with both -- the port (`dazzle -t pdf`, the binary in
$DAZZLE, else scalyc/build/dazzle of a Scaly checkout beside this one) and
Dazzle.Pdf (tools/oracle, built on first use with dotnet) -- with the same
font files (--fonts, default the system's supplemental fonts on macOS), and
compares what both pages show: every word with its box (pdftotext -bbox),
page by page and in reading order, and the pages' sizes. A word that differs,
or stands more than the tolerance (default 0.5 pt) away from its place in the
other, is reported; the exit status is 1 when anything is.

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
    env = dict(os.environ, DAZZLE_FONTS=fonts, SP_CHARSET_FIXED="YES", SP_ENCODING="XML")
    # an XML document is read after the SGML declaration of XML, as onsgmls
    # reads one; Dazzle.Pdf has it built in
    xml_dcl = os.path.join(ROOT, "upstream", "pubtext", "xml.dcl")
    p = subprocess.run([port_binary(), "-t", "pdf", "-o", port_pdf, "-d", dsl, xml_dcl, doc], env=env,
                       capture_output=True, text=True)
    if p.returncode != 0 or p.stderr.strip():
        return ["port: rc=%d %s" % (p.returncode, p.stderr.strip()[:400])]
    o = subprocess.run(["dotnet", oracle, doc, dsl, oracle_pdf, os.path.join(work, name + ".oracle.json"), fonts],
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
