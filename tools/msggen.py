#!/usr/bin/env python3
# tools/msggen.py — generate a Scaly message-table source file from an OpenSP
# .msg catalog. A faithful port of upstream/opensp/msggen.pl's .msg PARSING
# (NOT a reinterpretation): same =N / deleted-line / field-split / %J-continuation
# / auxiliary-fragment rules. Emits Scaly (one accessor function per tag) instead
# of C++ .h/.cxx.
#
# Usage:
#   tools/msggen.py <path-to>/ParserMessages.msg > <out>/ParserMessages.scaly
#
# The checked-in output under packages/opensp/0.1.0/opensp/ is byte-exact
# generator output — regenerate + diff, never hand-edit. See ./mkp (msggen step).
#
# Message SOURCING: the diagnostic text + severity + ISO clause + arg count come
# from the .msg (what real onsgmls prints — the single source of truth). Each tag
# becomes a zero-arg accessor returning its MessageType (or MessageFragment for a
# plain fragment with no severity letter); an auxiliary "start tag was here"-style
# fragment gets a companion <tag>_aux() accessor. The message NUMBER is stored for
# faithfulness (fragment.number) but is NOT printed by the plain drop-in format.

import os
import sys

# Severity letter -> Scaly Message.Severity variant (matches Message.scaly
# severity_char()): I->Info, W->Warning, Q->QuantityError, X->IdrefError, E->Error.
SEVERITY = {
    "I": "Info",
    "W": "Warning",
    "Q": "QuantityError",
    "X": "IdrefError",
    "E": "Error",
}


def escape(s):
    # msggen.pl: s|\\|\\\\|g then s|"|\\"|g  (backslash first, then quote).
    return s.replace("\\", "\\\\").replace('"', '\\"')


class Entry:
    __slots__ = ("num", "sev", "argc", "tag", "clause", "text", "aux_num", "aux_text")

    def __init__(self):
        self.num = 0
        self.sev = ""       # "" = plain fragment (no severity letter)
        self.argc = 0
        self.tag = ""
        self.clause = ""
        self.text = ""
        self.aux_num = None
        self.aux_text = None


def die(def_file, lineno, msg):
    sys.stderr.write("%s:%d: %s\n" % (def_file, lineno, msg))
    sys.exit(1)


def parse(def_file):
    entries = []
    num = 0
    lineno = 0
    with open(def_file, "r", encoding="utf-8") as f:
        for raw in f:
            lineno += 1
            line = raw.rstrip("\n")
            if line == "!cxx":
                continue
            if line.startswith("="):
                n = int(line[1:])
                if n < num:
                    die(def_file, lineno, "= directive must increase message num")
                num = n
                continue
            if line.startswith("-"):
                # a deleted message: consumes a number, no text.
                num += 1
                continue
            stripped = line.lstrip(" \t")
            if stripped.startswith("#"):
                continue
            if stripped == "":
                continue

            field = line.split("+", 4)  # <= 5 fields
            if len(field) < 4:
                die(def_file, lineno, "too few fields")

            # %J continuation: field[4] starting with %J appends to field[3].
            if len(field) == 5 and field[4].startswith("%J"):
                field[3] = field[3] + "+" + field[4][2:]
                field = field[:4]

            e = Entry()
            e.num = num
            if field[0] == "":
                e.sev = ""
                e.argc = 0
            else:
                if len(field[0]) != 2 or field[0][0] not in SEVERITY or not field[0][1].isdigit():
                    die(def_file, lineno, "invalid first field")
                e.sev = field[0][0]
                e.argc = int(field[0][1])
            e.tag = field[1]
            e.clause = field[2]
            e.text = field[3]

            # auxiliary fragment: a 5th field that is NOT a %J continuation.
            has_aux = len(field) == 5
            num += 1
            if has_aux:
                e.aux_num = num
                e.aux_text = field[4]
                num += 1
            entries.append(e)
    return entries


def emit(def_file, entries, out):
    cls = os.path.basename(def_file)
    cls = cls[: cls.rfind(".")] if "." in cls else cls

    w = out.write
    w("; This file was automatically generated from %s by tools/msggen.py.\n" % os.path.basename(def_file))
    w("; DO NOT EDIT: edit tools/msggen.py + the .msg catalog, then regenerate.\n")
    w(";\n")
    w("; Message text + severity + ISO clause are SOURCED from the OpenSP .msg\n")
    w("; catalog (what real onsgmls prints). One accessor per tag; an auxiliary\n")
    w("; fragment gets a companion <tag>_aux() accessor.\n")
    w("\n")
    w("use opensp.StringC.StringC\n")
    w("use opensp.Message.MessageType\n")
    w("use opensp.Message.MessageFragment\n")
    w("use opensp.Message.Severity\n")
    w("\n")
    w("define %s ()\n" % cls)
    w("{\n")

    first = True
    for e in entries:
        if not first:
            w("\n")
        first = False
        clause = (" " + e.clause) if e.clause else ""
        if e.sev == "":
            w("    ; %d%s (fragment)\n" % (e.num, clause))
            w("    function %s() returns MessageFragment\n" % e.tag)
            w('        MessageFragment(%d as u32, "%s")\n' % (e.num, escape(e.text)))
        else:
            w("    ; %d%s\n" % (e.num, clause))
            w("    function %s() returns MessageType\n" % e.tag)
            if e.clause:
                # MessageType::clauses_ — the -x "relevant clauses:" payload.
                w('        MessageType(MessageFragment(%d as u32, "%s"), Severity.%s, "%s")\n'
                  % (e.num, escape(e.text), SEVERITY[e.sev], escape(e.clause)))
            else:
                w('        MessageType(MessageFragment(%d as u32, "%s"), Severity.%s)\n'
                  % (e.num, escape(e.text), SEVERITY[e.sev]))
        if e.aux_num is not None:
            w("\n")
            w("    ; %d (auxiliary fragment of %s)\n" % (e.aux_num, e.tag))
            w("    function %s_aux() returns MessageFragment\n" % e.tag)
            w('        MessageFragment(%d as u32, "%s")\n' % (e.aux_num, escape(e.aux_text)))

    w("}\n")


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: msggen.py <catalog.msg>\n")
        sys.exit(2)
    def_file = sys.argv[1]
    entries = parse(def_file)
    emit(def_file, entries, sys.stdout)


if __name__ == "__main__":
    main()
