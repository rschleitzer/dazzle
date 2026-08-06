#!/usr/bin/env python3
"""refprof.py — leaf (self) profile per symbol from macOS `sample` output.

The reference column for tests/dazzle/primprof. `sample`'s own "Sort by top of
stack" block collapses everything under 5 samples, which is exactly the tail a
per-primitive comparison needs, so the self time is recomputed from the call
graph instead: a frame's self time is its count minus the sum of its direct
children's counts.

    refprof.py [--filter SUBSTR] out1.txt out2.txt ...

Sums across files, so the documented recipe (`sample <bin> 20 1 -wait -f out`
before each of N workload runs) aggregates into one distribution.
"""
import re
import sys

LINE = re.compile(r'^(\s*[|+!:\s]*?)(\d+) (.+?)  \(in ([^)]*)\)')


def parse(path, self_time, total):
    stack = []  # (depth, remaining, symbol)
    for raw in open(path, errors='replace'):
        m = LINE.match(raw)
        if not m:
            continue
        depth = len(m.group(1))
        count = int(m.group(2))
        sym = m.group(3).strip()
        # strip the trailing "+ 1004" offset sample appends to the symbol
        sym = re.sub(r'\s*\+\s*\d+$', '', sym)
        while stack and stack[-1][0] >= depth:
            d, rem, s = stack.pop()
            self_time[s] = self_time.get(s, 0) + rem
        if stack:
            stack[-1][1] -= count
        else:
            total[0] += count
        stack.append([depth, count, sym])
    while stack:
        d, rem, s = stack.pop()
        self_time[s] = self_time.get(s, 0) + rem


def main():
    args = sys.argv[1:]
    filt = None
    if args and args[0] == '--filter':
        filt = args[1]
        args = args[2:]
    self_time, total = {}, [0]
    for p in args:
        parse(p, self_time, total)
    tot = total[0] or 1
    rows = sorted(self_time.items(), key=lambda kv: -kv[1])
    print("refprof: %d samples over %d file(s)" % (tot, len(args)))
    print("refprof: %8s %10s  %s" % ("cpu%", "samples", "symbol"))
    for sym, n in rows:
        if n <= 0:
            continue
        if filt and filt not in sym:
            continue
        print("refprof: %7.3f%% %10d  %s" % (100.0 * n / tot, n, sym))


if __name__ == '__main__':
    main()
