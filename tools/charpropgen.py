#!/usr/bin/env python3
"""Transcribe ~/repos/dazzle/style/charProps.h into Scaly const arrays.

The reference keeps the built-in character-property tables as C initializer
rows behind #ifdef guards and #includes the file once per property. Each
guard has its own row shape:

  SPACE / RECORD_END / BLANK / INPUT_TAB / INPUT_WHITESPACE / PUNCT
      { first, count }                       -> a run that is #t
  SCRIPT
      { first, last, "Name" }                -> a range whose value is
                                                "ISO/IEC 10179::1996//Script::" + Name
  BREAK_PRIORITIES
      { first, count, bbp, bap }             -> two integer runs

Emitted as flat one-line `define X: int[] [...]` arrays (pairs / triples /
quads), so the Scaly side walks them with a fixed stride and no parsing.
The array literal MUST stay on one line — an LF inside the brackets ends the
construct. The script NAMES are printed as a trailing comment block and are
transcribed by hand into CharProps.append_script_name (a function may not
return a `pointer[const_char]` literal).

Usage:  tools/charpropgen.py > /tmp/cp.scaly
        then splice the tables into
        packages/dazzle/0.1.0/dazzle/CharProps.scaly (the install code below
        them is hand-written).
"""
import re, sys, os

SRC = os.path.expanduser("~/repos/dazzle/style/charProps.h")

def rows(guard):
    out, on = [], False
    for line in open(SRC):
        s = line.strip()
        if s.startswith("#ifdef"):
            on = (s.split()[1] == guard); continue
        if s.startswith("#endif"):
            on = False; continue
        if not on or not s.startswith("{"):
            continue
        body = s[s.index("{") + 1: s.rindex("}")]
        parts = [p.strip() for p in body.split(",")]
        out.append(parts)
    return out

def num(x):
    return int(x, 16) if x.lower().startswith("0x") else int(x)

def emit_pairs(name, guard, comment):
    r = rows(guard)
    vals = []
    for p in r:
        first, count = num(p[0]), num(p[1])
        vals += [first, first + count - 1]
    body = ", ".join("0x%04X" % v for v in vals)
    return ("; %s — %d ranges, flat [first, last, ...]\ndefine %s: int[] [%s]\n"
            % (comment, len(r), name, body))

def emit_script():
    r = rows("SCRIPT")
    names, idx = [], {}
    trips = []
    for p in r:
        first, last = num(p[0]), num(p[1])
        nm = p[2].strip().strip('"')
        if nm not in idx:
            idx[nm] = len(names); names.append(nm)
        trips += [first, last, idx[nm]]
    body = ", ".join("0x%04X" % v for v in trips)
    tbl = ("; the `script` property: %d ranges, flat [first, last, name-index].\n"
           "; The VALUE is the prefix \"ISO/IEC 10179::1996//Script::\" plus the\n"
           "; name, built once per index at install time.\n"
           "define CP_SCRIPT: int[] [%s]\n" % (len(r), body))
    return tbl, names

def emit_break():
    r = rows("BREAK_PRIORITIES")
    vals = []
    for p in r:
        first, count, bbp, bap = (num(p[0]), num(p[1]), num(p[2]), num(p[3]))
        vals += [first, first + count - 1, bbp, bap]
    body = ", ".join("0x%04X" % v for v in vals)
    return ("; break-before-priority / break-after-priority: %d ranges, flat\n"
            "; [first, last, before, after]. Generated in the reference by\n"
            "; unicode/genbreakprios.pl and transcribed here unchanged.\n"
            "define CP_BREAK: int[] [%s]\n" % (len(r), body))

parts = [
 emit_pairs("CP_SPACE", "SPACE", "the `space?` property"),
 emit_pairs("CP_RECORD_END", "RECORD_END", "the `record-end?` property"),
 emit_pairs("CP_BLANK", "BLANK", "the `blank?` property"),
 emit_pairs("CP_INPUT_TAB", "INPUT_TAB", "the `input-tab?` property"),
 emit_pairs("CP_INPUT_WHITESPACE", "INPUT_WHITESPACE", "the `input-whitespace?` property"),
 emit_pairs("CP_PUNCT", "PUNCT", "the `punct?` property"),
]
script_tbl, script_names = emit_script()
parts.append(script_tbl)
parts.append(emit_break())

print("\n".join(parts))
print("; script names, indexed by the third column of CP_SCRIPT")
for i, n in enumerate(script_names):
    print(';   %2d %s' % (i, n))
print("SCRIPT_NAMES = %r" % (script_names,), file=sys.stderr)
