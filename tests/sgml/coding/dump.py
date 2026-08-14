#!/usr/bin/env python3
"""Byte dump for the coding-system golden — deliberately NOT `od`.

The golden records raw bytes (several cells emit UTF-16), so it needs a dump
that is identical on every host. `od -c` is not: it differs in TWO independent
ways, and each one silently bakes the minting host into the golden.

  1. LOCALE. BSD/macOS od decodes multibyte sequences and prints the CHARACTER
     followed by `**` for every continuation byte; GNU od always prints octal.
     The same two bytes read `ü  **` there and `303 274` here.
  2. IMPLEMENTATION. BSD od -An indents every line by eight further columns,
     pads the final line to full width and adds a trailing blank line. That one
     survives LC_ALL=C, because it is not a locale question at all.

Both were found on 2026-08-14, when the bar ran this suite on Linux for the
first time and all 231 cells mismatched while the parser output was correct to
the byte. Normalising the difference away in the COMPARISON would have been the
wrong fix — that decides the difference does not matter. This dumper is the
instrument made portable instead.

The format is GNU `od -An -c`: sixteen bytes per line, each in a four-column
right-aligned field, C escapes for the named control characters, three-digit
octal for everything else. Reproduced here rather than shelled out to, so the
output depends on nothing but this file.
"""
import sys

ESC = {0x00: r"\0", 0x07: r"\a", 0x08: r"\b", 0x09: r"\t",
       0x0a: r"\n", 0x0b: r"\v", 0x0c: r"\f", 0x0d: r"\r"}


def rep(b):
    if b in ESC:
        return ESC[b]
    if 0x20 <= b <= 0x7e:
        return chr(b)
    return "%03o" % b


def main():
    if len(sys.argv) > 1:
        data = open(sys.argv[1], "rb").read()
    else:
        data = sys.stdin.buffer.read()
    out = []
    for i in range(0, len(data), 16):
        out.append("".join("%4s" % rep(b) for b in data[i:i + 16]))
    sys.stdout.write("".join(line + "\n" for line in out))


if __name__ == "__main__":
    main()
