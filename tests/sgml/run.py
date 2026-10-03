#!/usr/bin/env python3
"""tests/sgml/run.py -- the dazzle/OpenSP corpus oracle (tests/sgml/run.sh is
its entry point; the account of the corpus, the manifests and the discovery
gate is in run.sh's header).

Replays the frozen SGML/XML corpus against an onsgmls-compatible binary and
compares its ESIS, exit code, normalised stderr and (RAST=1) its -t output with
the goldens. Prints the counter

    N of M models ESIS-identical

A driver and not a shell loop since 2026-10-03 (tests/win32/WINDOWS-BOX.md §8):
the loop forked ~10 processes per model -- basename, a subshell, sed, three
diffs, cats -- and on Windows every fork is emulated by the MSYS runtime
(~59 ms measured, against ~8 ms for a CreateProcess from here), so the corpus
spent minutes starting processes, on one core. Here a model costs exactly the
binary's own process, the comparisons happen in memory, and the models run in
parallel; the output, the verdicts and the exit codes are the loop's.

Usage:
  run.py [binary]                 replay (default binary: onsgmls on PATH)
  run.py --bless [binary]         regenerate goldens from binary
  run.py --filter <glob>          only entries whose name matches
  run.py --jobs <n>               parallel models (default: every core)
"""
import concurrent.futures
import fnmatch
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(HERE))


def fail_usage(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)


def parse_args(argv):
    bless, filt, binary, jobs = False, "*", "", os.cpu_count() or 4
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--bless":
            bless = True
        elif a == "--filter":
            i += 1
            if i == len(argv):
                fail_usage("--filter needs a glob")
            filt = argv[i]
        elif a == "--jobs":
            i += 1
            if i == len(argv) or not argv[i].isdigit() or int(argv[i]) < 1:
                fail_usage("--jobs needs a positive number")
            jobs = int(argv[i])
        elif a.startswith("-"):
            fail_usage("unknown flag: " + a)
        else:
            binary = a
        i += 1
    return bless, filt, binary or "onsgmls", jobs


def resolve_binary(binary):
    """-> (argv0, argv prefix, executable). argv0 is what the program sees as
    its name: the diagnostics begin with it, and the comparison strips
    everything up to the FIRST colon, so it must not carry one -- a Windows
    path does (`C:\\...`), which is why a native binary is started under the
    name it was GIVEN while the executable is its full path. A script (CI hands
    tests/win32/lf-wrapper.sh) is started through bash on Windows, which cannot
    run one directly."""
    path = binary if (os.sep in binary or "/" in binary) else shutil.which(binary)
    if path is None or not os.path.exists(path):
        alt = (path or binary) + ".exe"
        if os.name == "nt" and os.path.exists(alt):
            path = alt
        else:
            fail_usage("binary not found: " + binary)
    path = os.path.abspath(path)
    with open(path, "rb") as fh:
        is_script = fh.read(2) == b"#!"
    if os.name == "nt" and is_script:
        bash = shutil.which("bash")
        if bash is None:
            fail_usage("binary is a script and no bash is on PATH: " + binary)
        # its own $0 becomes the program's name (lf-wrapper.sh's LFW_NAME), so
        # hand it the POSIX spelling a bash caller would, which has no colon
        cygpath = shutil.which("cygpath")
        if cygpath is not None:
            path = subprocess.run([cygpath, "-u", path], stdout=subprocess.PIPE,
                                  text=True).stdout.strip() or path
        return binary, [binary], bash, [path]
    argv0 = binary
    if os.name == "nt":
        argv0 = os.path.splitext(binary.replace("\\", "/"))[0]
        if ":" in argv0:
            argv0 = os.path.basename(argv0)
    return argv0, [argv0], path, []


MANIFEST_LINE = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)=(.*)$')


def read_manifest(path):
    """The manifests are written as shell (run.sh sourced them) but use one
    shape only: KEY=VALUE or KEY="VALUE". Anything else is refused by name
    rather than misread."""
    vals = {}
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            m = MANIFEST_LINE.match(s)
            if not m:
                raise ValueError("%s:%d: not KEY=VALUE: %r" % (path, n, s))
            v = m.group(2)
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                v = v[1:-1]
            if any(c in v for c in "$`\\\"'*?[;&|<>()"):
                raise ValueError("%s:%d: shell syntax the driver does not read: %r" % (path, n, s))
            vals[m.group(1)] = v
    return vals


NORM = re.compile(rb"(?m)^[^:\n]*:")


def norm_err(data):
    """Diagnostics are compared EXCEPT the leading program name (argv[0]),
    which differs between the real onsgmls and the drop-in: everything up to
    the first colon of each line goes."""
    return NORM.sub(b"", data)


def read_bytes(path):
    try:
        with open(path, "rb") as fh:
            return fh.read()
    except OSError:
        return None


def exit_text(rc):
    # what bash's $? said: a signal is 128 + its number
    return str(128 - rc if rc < 0 else rc)


def command(launch, args):
    """-> (argv, executable) for subprocess: a native binary under the name it
    was given, a script through bash with its full path."""
    argv0_prefix, executable, script = launch
    if script:
        return [executable] + script + args, None
    return argv0_prefix + args, executable


def run_entry(entry, name, tmp, bless, launch):
    """One model -> (counts_total, ok, message or None, failed name or None)."""
    try:
        m = read_manifest(os.path.join(entry, "manifest"))
    except ValueError as e:
        return (0, 0, "  %s: %s" % (name, e), name)
    doc = m.get("DOC", "")
    if not doc:
        return (0, 0, "  %s: manifest missing DOC" % name, None)
    workdir_v, base = m.get("WORKDIR", ""), m.get("BASE", "entry")
    if workdir_v:
        workdir = workdir_v if os.path.isabs(workdir_v) or workdir_v.startswith("/") \
            else os.path.join(entry, workdir_v)
    elif base == "repo":
        workdir = REPO_ROOT
    elif base == "entry":
        workdir = entry
    else:
        return (0, 0, "  %s: bad BASE=%s" % (name, base), None)
    if not os.path.isdir(workdir):
        return (0, 0, "  %s: workdir missing (%s) — skipped (fetch-private.sh?)" % (name, workdir), None)

    got_rast = os.path.join(tmp, name + ".rast")
    args = []
    if m.get("RAST") == "1":
        args += ["-t", got_rast]
    args += m.get("EXTRA_ARGS", "").split() + [doc]
    env = dict(os.environ)
    for kv in m.get("SP_ENV", "").split():
        k, _, v = kv.partition("=")
        env[k] = v
    cmd, exe = command(launch, args)
    p = subprocess.run(cmd, executable=exe, cwd=workdir, env=env, stdin=subprocess.DEVNULL,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    got_esis, got_exit, got_err = p.stdout, exit_text(p.returncode), norm_err(p.stderr)

    if bless:
        with open(os.path.join(entry, "expected.esis"), "wb") as fh:
            fh.write(got_esis)
        with open(os.path.join(entry, "expected.exit"), "w", newline="\n") as fh:
            fh.write(got_exit + "\n")
        with open(os.path.join(entry, "expected.err"), "wb") as fh:
            fh.write(got_err)
        if m.get("RAST") == "1":
            shutil.copyfile(got_rast, os.path.join(entry, "expected.rast"))
        return (1, 1, "  blessed " + name, None)

    want_esis = read_bytes(os.path.join(entry, "expected.esis"))
    if want_esis is None:
        return (1, 0, "  %s: NO GOLDEN (run --bless)" % name, name)
    want_err = read_bytes(os.path.join(entry, "expected.err"))
    err_ok = want_err is None or want_err == got_err
    rast_ok = True
    if m.get("RAST") == "1":
        rast_ok = read_bytes(os.path.join(entry, "expected.rast")) == read_bytes(got_rast)
    want_exit = (read_bytes(os.path.join(entry, "expected.exit")) or b"").decode().rstrip("\n")
    if want_esis == got_esis and want_exit == got_exit and err_ok and rast_ok:
        return (1, 1, None, None)
    reason = "exit want=%s got=%s" % (want_exit, got_exit)
    if not err_ok:
        reason += "; stderr differs"
    if not rast_ok:
        reason += "; rast differs"
    return (1, 0, "  MISMATCH %s (%s)" % (name, reason), name)


def stdin_check(launch):
    """The stdin fidelity check (S85). A stdin document (`<OSFD>0`, no
    inheritable storage object) consults NO implicit `catalog` -- the port used
    to read the CWD's catalog, so a stray cwd catalog's SGMLDECL (this repo's
    `catalog` -> scaly.dcl) silently re-declared stdin parses (namecase off,
    reserved names rejected). Run from the repo root, where exactly that
    catalog exists; expect the reference concrete syntax (upcased GIs, `o o`
    minimization accepted). Golden verified against real onsgmls 1.5.2."""
    doc = b"<!DOCTYPE a [\n<!ELEMENT a o o (#pcdata)>\n]>\n<a>hi</a>\n"
    cmd, exe = command(launch, [])
    p = subprocess.run(cmd, executable=exe, cwd=REPO_ROOT, input=doc,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    got = p.stdout.rstrip(b"\n")
    return p.returncode == 0 and got == b"(A\n-hi\n)A\nC", p.returncode, got


def discovery_gate(pub_seen, priv_seen):
    """The DISCOVERY gate. "N of M ESIS-identical" only means something if M is
    the corpus we expect. A shrinking M is invisible in that line -- a renamed
    directory, a manifest that lost its DOC, an unfetched private tier, and the
    suite happily reports "366 of 366" with rc 0 while a hundred models
    silently stopped running. So the expected count is written down and
    compared in BOTH directions: fewer is a corpus that fell out, more is a
    corpus that grew, and both must be a deliberate edit of the file rather
    than a number nobody reads.

    The public tier is committed, so its count is committed too. The private
    tier is gitignored and optional (CI has none): its expectation lives in the
    tier itself, written by fetch/freeze, and is only checked when the tier is
    present. Skipped under --filter: a filtered run is a selection, not a
    corpus."""
    rc = 0
    pub_want_file = os.path.join(HERE, "expected-models")
    if os.path.isfile(pub_want_file):
        pub_want = re.sub(r"\D", "", open(pub_want_file).read())
        if str(pub_seen) != pub_want:
            print("  CORPUS public tier has %d models, expected %s" % (pub_seen, pub_want))
            print("  (if that change is intended, edit tests/sgml/expected-models)")
            rc = 1
    else:
        print("  CORPUS no tests/sgml/expected-models — discovery is ungated")
        rc = 1
    priv_want_file = os.path.join(HERE, "corpus-private", "expected-models")
    if os.path.isfile(priv_want_file):
        priv_want = re.sub(r"\D", "", open(priv_want_file).read())
        if str(priv_seen) != priv_want:
            print("  CORPUS private tier has %d models, expected %s" % (priv_seen, priv_want))
            print("  (if that change is intended, edit tests/sgml/corpus-private/expected-models)")
            rc = 1
    elif priv_seen > 0:
        print("  CORPUS private tier present (%d models) but not gated —" % priv_seen)
        print("  write the count to tests/sgml/corpus-private/expected-models")
    return rc


def main():
    bless, filt, binary, jobs = parse_args(sys.argv[1:])
    argv0, argv0_prefix, executable, script = resolve_binary(binary)
    launch = (argv0_prefix, executable, script)

    entries, pub_seen, priv_seen = [], 0, 0
    for tier in ("corpus", "corpus-private"):
        for entry in sorted(glob.glob(os.path.join(HERE, tier, "*", ""))):
            entry = entry.rstrip("/\\")
            if not os.path.isfile(os.path.join(entry, "manifest")):
                continue
            name = os.path.basename(entry)
            if tier == "corpus":
                pub_seen += 1
            else:
                priv_seen += 1
            if fnmatch.fnmatchcase(name, filt):
                entries.append((entry, name))

    tmp = tempfile.mkdtemp(prefix="sgml-")
    total = ok = 0
    failed = []
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
            results = pool.map(lambda e: run_entry(e[0], e[1], tmp, bless, launch), entries)
            for t, k, msg, bad in results:
                total += t
                ok += k
                if msg:
                    print(msg, flush=True)
                if bad:
                    failed.append(bad)
        if not bless:
            good, rc, got = stdin_check(launch)
            if not good:
                print("  MISMATCH stdin-no-doc-catalog (rc=%d)" % rc)
                print("\n".join(got.decode(errors="replace").split("\n")[:4]))
                failed.append("stdin-no-doc-catalog")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print()
    gate_rc = discovery_gate(pub_seen, priv_seen) if filt == "*" else 0
    if bless:
        print("blessed %d of %d models" % (ok, total))
    else:
        print("%d of %d models ESIS-identical" % (ok, total))
        if failed:
            print("failed: " + " ".join(failed))
            sys.exit(1)
    sys.exit(1 if gate_rc else 0)


if __name__ == "__main__":
    main()
