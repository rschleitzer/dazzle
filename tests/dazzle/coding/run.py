#!/usr/bin/env python3
"""tests/dazzle/coding/run.py -- the cells of the coding matrix (run.sh is the
entry point: it builds dazzle, writes the inputs into the work directory, and
compares the matrix with expected.txt or blesses it).

Writes the matrix BYTE-IDENTICAL to the shell loop it replaces: per cell
`=== <label> rc=<n>`, the dazzle stdout as `od -An -tx1 | tr -s ' ' | sed`
printed it (16 bytes a line, a run of identical lines as one `*`), `--- stderr`
with each line's program name replaced by PROG, and every file the cell wrote,
by name in C order. A driver and not the loop since 2026-10-03
(tests/win32/WINDOWS-BOX.md §8): each of the 228 cells forked some fifteen
processes around its one dazzle run, and Git Bash emulates every fork -- the
suite was 320 s on the Windows box, the slowest of the bar's dazzle lane by six.
The cells now run in parallel, each in a directory of its own.

  run.py <dazzle binary> <work dir with the inputs> <matrix out> [--jobs n]
"""
import concurrent.futures
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

CONFIGS = [("default", ""), ("enc-utf8", "SP_ENCODING=UTF-8"), ("enc-8859-1", "SP_ENCODING=ISO-8859-1"),
           ("enc-koi8", "SP_ENCODING=KOI8-R"), ("enc-eucjp", "SP_ENCODING=EUC-JP"),
           ("enc-xml-fixed", "SP_CHARSET_FIXED=YES SP_ENCODING=XML"),
           ("enc-unknown", "SP_ENCODING=NO-SUCH-CS"), ("enc-ucs2", "SP_ENCODING=UCS-2"),
           ("bctf-utf8", "SP_BCTF=UTF-8")]
BEES = [("none", ""), ("b-utf8", "-bUTF-8"), ("b-8859-1", "-bISO-8859-1"), ("b-unicode", "-bUNICODE"),
        ("b-eucjp", "-bEUC-JP"), ("b-unknown", "-bNO-SUCH-CS")]


def cells():
    """(label, environment assignments, dazzle arguments), in the loop's order."""
    out = []
    for cname, cenv in CONFIGS:
        for bname, barg in BEES:
            for t in ("fot", "sgml", "xml", "html"):
                b = [barg] if barg else []
                out.append(("%s %s %s" % (cname, bname, t), cenv,
                            ["-t", t, "-d", "enc.dsl"] + b + ["-o", "out." + t, "d.sgml"]))
    for t in ("rtf", "tex", "mif"):
        out.append(("control none " + t, "", ["-t", t, "-d", "enc.dsl", "-o", "out." + t, "d.sgml"]))
        out.append(("control b-unicode " + t, "",
                    ["-t", t, "-d", "enc.dsl", "-bUNICODE", "-o", "out." + t, "d.sgml"]))
        out.append(("control enc-koi8 " + t, "SP_ENCODING=KOI8-R",
                    ["-t", t, "-d", "enc.dsl", "-o", "out." + t, "d.sgml"]))
    for b in ("", "-bUNICODE", "-bEUC-JP"):
        out.append(("entity %s sgml" % (b or "none"), "",
                    ["-t", "sgml", "-d", "ent.dsl"] + ([b] if b else []) + ["plain.sgml"]))
    return out


def dump(data):
    """`od -An -tx1 | tr -s ' ' | sed 's/^ *//; s/ *$//; /^$/d'`, measured
    identical: 16 bytes a line, and a run of 16-byte lines equal to the one
    before printed once as `*`.

    The account, from the shell loop it replaces:

    ★A BYTE DUMP THAT EVERY `od` AGREES ON (2026-08-10, stage 7 rung 8). This
    used to be `od -An -c`, whose COLUMN LAYOUT is implementation-defined: BSD od
    (the dev box, where the goldens were minted) pads far wider than the GNU od in
    Git Bash, so on Windows all 228 cells "differed" while every byte was in fact
    identical — a whole suite red for a formatting convention.
    
    ★The obvious repair is wrong and was measured before being discarded:
    squeezing the spaces out of `-c` output is AMBIGUOUS, because a space BYTE is
    rendered as spaces too — `a b` and `ab` both collapse to ` a b `, so two
    different byte streams would compare equal. That is a silent loosening of the
    very test that exists to catch byte differences. `-tx1` has no such hole:
    every byte is exactly two hex digits, so squeezing separators cannot conflate
    anything. Leading and trailing padding go too, since BSD pads the line and GNU
    does not.
    ★The blank line goes too: `od` ends with a TOTAL-LENGTH offset line, which
    `-An` renders as an empty line — and whether a given implementation emits it
    at all is exactly the kind of thing this helper exists to stop mattering. It
    carries no information here (sections are delimited by `--- ` markers), and a
    zero-byte stream still dumps to no lines, which is unambiguous.
    """
    lines, prev, star = [], None, False
    for i in range(0, len(data), 16):
        block = data[i:i + 16]
        if block == prev and len(block) == 16:
            if not star:
                lines.append("*")
                star = True
            continue
        star = False
        prev = block
        lines.append(" ".join("%02x" % b for b in block))
    return "".join(line + "\n" for line in lines)


PROG = re.compile(rb"(?m)^[^:\n]*:")


def is_input(name):
    return name in ("d.sgml", "plain.sgml", "cell.out", "cell.err") or \
        name.endswith(".dsl") or name.endswith(".scm")


def launch(binary):
    """-> (argv prefix, executable): a native binary under the name it was given
    (stderr's program name is replaced by PROG up to the FIRST colon, so the name
    must not carry one -- `C:\\...` does); a script through bash on Windows."""
    path = os.path.abspath(binary)
    with open(path, "rb") as fh:
        script = fh.read(2) == b"#!"
    if os.name == "nt" and script:
        bash = shutil.which("bash")
        cygpath = shutil.which("cygpath")
        posix = subprocess.run([cygpath, "-u", path], stdout=subprocess.PIPE,
                               text=True).stdout.strip() if cygpath else path
        return [bash, posix], None
    name = os.path.splitext(os.path.basename(binary))[0] if os.name == "nt" else binary
    return [name], path


def run_cell(i, cell, work, prefix, exe):
    label, cenv, args = cell
    d = os.path.join(work, "cell%03d" % i)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    for f in os.listdir(work):
        src = os.path.join(work, f)
        if os.path.isfile(src) and (f in ("d.sgml", "plain.sgml") or f.endswith(".dsl") or f.endswith(".scm")):
            shutil.copyfile(src, os.path.join(d, f))
    env = dict(os.environ)
    for k in ("SP_ENCODING", "SP_BCTF", "SP_CHARSET_FIXED"):
        env.pop(k, None)
    env["SCALY_HOME"] = ROOT
    for kv in cenv.split():
        k, _, v = kv.partition("=")
        env[k] = v
    p = subprocess.run(prefix + args, executable=exe, cwd=d, env=env,
                       stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    rc = p.returncode
    rc = 128 - rc if rc < 0 else rc
    out = ["=== %s rc=%d\n" % (label, rc), dump(p.stdout), "--- stderr\n",
           dump(PROG.sub(b"PROG:", p.stderr))]
    for f in sorted(os.listdir(d), key=lambda n: n.encode()):
        if is_input(f):
            continue
        out.append("--- file %s\n" % f)
        out.append(dump(open(os.path.join(d, f), "rb").read()))
    shutil.rmtree(d, ignore_errors=True)
    return "".join(out)


def main():
    binary, work, matrix = sys.argv[1], sys.argv[2], sys.argv[3]
    jobs = os.cpu_count() or 4
    if len(sys.argv) > 5 and sys.argv[4] == "--jobs":
        jobs = int(sys.argv[5])
    prefix, exe = launch(binary)
    todo = cells()
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        blocks = list(pool.map(lambda ic: run_cell(ic[0], ic[1], work, prefix, exe), enumerate(todo)))
    with open(matrix, "w", newline="\n") as fh:
        fh.write("".join(blocks))


if __name__ == "__main__":
    main()
