#!/usr/bin/env python3
# tools/chartablegen.py — generate a Scaly char-name table source for the
# dazzle package from openjade's charNames.h / sdata.h include tables
# (upstream/openjade/style). Same sourcing doctrine as msggen.py: the
# reference table IS the data; the checked-in output is byte-exact
# generator output — regenerate + diff, never hand-edit. See ./mkp.
#
# Usage:
#   tools/chartablegen.py CharNames  <path>/charNames.h > .../CharNames.scaly
#   tools/chartablegen.py Sdata      <path>/sdata.h     > .../Sdata.scaly
#
# Each entry line looks like:  { 0x00c0, "Agrave" },
# and becomes one interp.def_char / interp.def_sdata_char call
# (namedCharTable_ / sdataEntityNameTable_ insert with defPart -1 —
# Interpreter::installCharNames / installSdata).

import re
import sys

# ★★★THE CONVERSIONS BELONG IN THE GENERATOR, NOT ONLY IN THE OUTPUT.
# Two campaigns had touched `CharNames.scaly`/`Sdata.scaly` without bringing
# this script into line: pointer[Interpreter] -> ref[Interpreter] (7 signatures
# per file) and the literal-cast sweep that removed the ` as u32` at each of
# the ~890 entries.  A regeneration run would have silently reverted
# both -- measured 2026-09-04 with a source table RECONSTRUCTED
# from the output: 1830 diff lines.  The openjade sources are missing
# on the development machine, so such a step back is NOT noticed here;
# `./mkp` only reports "skipping" for it.
CHUNK = 150  # entries per install_<i> function (keeps single bodies small)

def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("CharNames", "Sdata"):
        print("usage: chartablegen.py CharNames|Sdata <table.h>", file=sys.stderr)
        return 1
    concept = sys.argv[1]
    path = sys.argv[2]
    call = "def_char" if concept == "CharNames" else "def_sdata_char"

    entries = []
    pat = re.compile(r'^\s*\{\s*(0[xX][0-9a-fA-F]+)\s*,\s*"([^"]+)"\s*\}\s*,?\s*$')
    with open(path, "r") as f:
        for line in f:
            m = pat.match(line)
            if m:
                entries.append((int(m.group(1), 16), m.group(2)))

    if not entries:
        print("chartablegen.py: no entries parsed from %s" % path, file=sys.stderr)
        return 1

    src = path.split("/")[-1]
    out = sys.stdout
    out.write("; This file was automatically generated from %s by tools/chartablegen.py.\n" % src)
    out.write("; DO NOT EDIT: edit tools/chartablegen.py + the reference table, then regenerate.\n")
    out.write(";\n")
    out.write("; Data SOURCED from openjade's style/%s (Interpreter::install%s):\n" % (src, "CharNames" if concept == "CharNames" else "Sdata"))
    out.write("; %d entries, inserted with defPart -1 (predefined, overridable by\n" % len(entries))
    out.write("; standard-chars / map-sdata-entity declarations from a spec part).\n")
    out.write("\n")
    out.write("use dazzle.Interpreter.Interpreter\n")
    out.write("\n")
    out.write("define %s ()\n" % concept)
    out.write("{\n")
    chunks = [entries[i:i + CHUNK] for i in range(0, len(entries), CHUNK)]
    out.write("    procedure install(interp: ref[Interpreter])\n")
    out.write("    {\n")
    for i in range(len(chunks)):
        out.write("        %s.install_%d(interp)\n" % (concept, i))
    out.write("    }\n")
    for i, chunk in enumerate(chunks):
        out.write("\n")
        out.write("    procedure install_%d(interp: ref[Interpreter])\n" % i)
        out.write("    {\n")
        for code, name in chunk:
            out.write('        interp.%s("%s", 0x%04X)\n' % (call, name, code))
        out.write("    }\n")
    out.write("}\n")
    return 0

if __name__ == "__main__":
    sys.exit(main())
