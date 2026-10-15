# dazzle

A DSSSL processor: OpenSP and OpenJade, the OpenJade Project's continuation
of James Clark's SP and Jade, ported from C++ to
[Scaly](https://scaly.io) — and, beyond the original, with a backend that
writes PDF: a DocBook book goes from its XML to a typeset PDF with one
program and no TeX in between.

DSSSL (ISO/IEC 10179) is the style and transformation language of SGML. An
engine reads an SGML or XML document, applies a stylesheet written in a Scheme
dialect, and writes the result through a backend. This repository holds the
whole chain twice:

- `packages/opensp` — the SGML parser, with the program `onsgmls`;
  `packages/dazzle` — the style engine, with the program `dazzle`, the
  original's backends and one of its own, PDF (below). Both are written in
  Scaly, a language with region-based memory management the compiler
  infers.
- `upstream/` — the C++ original they were ported from (OpenSP 1.5.2 and
  OpenJade 1.3 with a few modifications), which still builds and remains
  the reference: where the two disagree, the port is wrong.

The port follows the original name by name and algorithm by algorithm. What
it changes is what the language changes: regions in place of reference
counting, sum types and pattern matching in place of class hierarchies and
virtual dispatch.

## Backends

SGML/XML transformation, RTF, TeX, MIF and HTML, as in the original, and the
flow object tree (`-t fot`).

One backend the original does not have, in the Scaly engine only: PDF
(`-t pdf`). It sets the pages itself and writes them with the
[pdf](https://github.com/rschleitzer/pdf) package. It is rudimentary: simple
page sequences with headers and footers, paragraphs, display groups, line
fields, leaders, rules, external graphics (JPEG, PNG) and tables — enough to
set a book with the DocBook print stylesheets, and not more.

A font family is looked for among the TrueType files of the system's font
directories, by the family name and style each file states, and embedded
with the glyphs the document uses; the text may be any Unicode the font has.
For a family the system lacks, its usual sans serif, serif or typewriter face
is taken instead. `DAZZLE_FONTS` names the directories to look in, separated
by colons, in place of the system's. Where no file is found, the text is set
in a standard font (Helvetica, Times, Courier), which has the characters of
Windows code page 1252 only.

```sh
./dazzle -t pdf -o book.pdf -d stylesheet.dsl document.xml
```

One addition to DSSSL, in both the C++ and the Scaly engine: the `directory`
flow object class. The transformation backend writes files through `entity`;
`directory` creates a directory and makes the entities inside it relative to
it, so a stylesheet can lay out a whole tree of generated files.

```scheme
(declare-flow-object-class directory
  "UNREGISTERED::Dazzle//Flow Object Class::directory")

(make directory path: "output"
  (make entity system-id: "file.txt"
    (make formatting-instruction data: "content")))
```

## Performance

Measured on a code generator in daily use:
[fire](https://github.com/rschleitzer/fire), a FHIR server generated from
HL7's definitions, with all 146 resource types active. Two stylesheets read
the same 4.7 MB model. One writes a server in Scaly (309 files: the model as
data, the program, a client package, a web root), the other a server in C#
(1459 files, 260 000 lines). Both engines write the same files, byte for
byte. Apple M4 (four performance and six efficiency cores), macOS 26, fire
at `b0b8fd1`, this repository at `ce76317`; the median of three runs of
`/usr/bin/time -l`:

| stylesheet | engine | wall | CPU | instructions | memory |
|---|---|---|---|---|---|
| Scaly server | C++ | 6.17 s | 6.04 s | 101.2 G | 158 MB |
| | Scaly | 4.61 s | 4.12 s | 52.9 G | 228 MB |
| C# server | C++ | 39.96 s | 39.54 s | 316.4 G | 147 MB |
| | Scaly | 4.82 s | 3.88 s | 73.1 G | 267 MB |

The C# stylesheet is where the original takes eight times as long. Both
engines define `node-list-filter` in DSSSL (`builtins.dsl`), as a fold of
`(node-list result snl)`: a chain of pairs, which the original walks again
for every member it is asked for, so going through a filtered list is
quadratic. The port flattens such a list once, on its first access. That
stylesheet filters often, some of it inside loops over the resources.

Memory goes the other way. The original collects garbage; the port keeps
what a run allocates, in regions, until the run ends. A stylesheet that
makes much garbage costs the port more memory than the original, and an
idiom that is quadratic in garbage costs it orders of magnitude more: the
Scaly stylesheet above took 7.3 GB (the original 151 MB) until its
`string-replace` stopped copying the whole string at every match.

To run it, in a checkout of fire:

```sh
export SP_ENCODING=utf-8
dazzle -t sgml -d codegen/scaly.dsl model/fhir.xml
cp model/fhir.xml upstream/ && cd upstream && dazzle -t sgml -d codegen/map.dsl fhir.xml
```

### Building it

The two code bases are of a size: the build of the original compiles about
136 000 lines of C++, the port is about 141 000 lines of Scaly in
`packages/opensp` and `packages/dazzle`.
Building them from scratch on the same machine, the median of three runs:
CPU is the user and system time of every process of the build, memory the
largest of any one process. The C++ build is `upstream/build.sh`: OpenSP's
library, `nsgmls` and `dazzle`, compiled with `-O2 -g` through libtool. The
Scaly build is `scaly build` of the program with the opensp, dazzle and pdf
packages (Scaly 0.2.13), its package cache holding the standard library
only.

| build | wall | CPU | memory |
|---|---|---|---|
| C++, configure and `make -j10` | 53.7 s | 117.2 s | 166 MB |
| C++, `make -j10` | 21.6 s | 103.8 s | 147 MB |
| C++, `make -j1` | 61.2 s | 55.5 s | 145 MB |
| Scaly, release | 17.1 s | 15.9 s | 3.4 GB |
| Scaly, debug | 20.2 s | 19.5 s | 3.6 GB |

On one core the port builds in about a quarter of the time the original
takes, and faster than the original on ten. It needs far more memory to do
it: the compiler is one process that holds the whole program.

After a change it goes the other way:

| changed | C++, `make -j10` | Scaly, release | Scaly, debug |
|---|---|---|---|
| nothing | 0.2 s | 10.6 s | 0.4 s |
| one source file | 1.8 s | 14.0 s | 11.1 s |

The original compiles the one file and links. The port compiles the whole
package the file belongs to, and a release build optimizes the whole program
again each time, even when nothing has changed. (The original's build is
configured without dependency tracking: after a change to a header, `make`
rebuilds nothing, and only a clean build is a correct one.)

## Install

With Scaly installed (`curl -fsSL https://scaly.io/install.sh | sh`, on
Windows `irm https://scaly.io/install.ps1 | iex`; see
[scaly.io/download](https://scaly.io/download/)) and `git` at hand:

```sh
scaly install github.com/rschleitzer/dazzle dazzle 0.1.2     # the program dazzle
scaly install github.com/rschleitzer/dazzle opensp 0.1.0     # the program onsgmls
```

fetches the package and what it uses, builds its program and puts it beside
`scaly` on the `PATH`.

## Build

Install Scaly (`curl -fsSL https://scaly.io/install.sh | sh`, on Windows
`irm https://scaly.io/install.ps1 | iex`, or see
[scaly.io/download](https://scaly.io/download/)). Then from this directory:

```sh
scaly build packages/dazzle/$(tools/version.sh dazzle)/programs/dazzle.scaly --release -o dazzle
scaly build packages/opensp/$(tools/version.sh opensp)/programs/onsgmls.scaly --release -o onsgmls
```

The compiler finds dazzle's own packages in `packages/` here and the standard
library in the installation. The [pdf](https://github.com/rschleitzer/pdf)
package is fetched with git the first time, into `~/.scaly/packages/`
(`%USERPROFILE%\.scaly\packages\` on Windows) — so the first build needs git
and the network. Its version 0.1.0 is frozen: every build takes the same
files, and the commit they were fetched at stands in `0.1.0.fetched` beside
them.

On macOS and Linux compiling the engine needs a 64 MB stack
(`ulimit -s 65520` in the shell first); on Windows the compiler brings its own.

A program built this way says the number of its package for its version (`dazzle -v`). The day
and the commit are stamped in by `tools/release.sh`, which builds what the
[releases](https://github.com/rschleitzer/dazzle/releases) hand out; the
`VERSION` file of a release names the pdf package too, by the git tree of
its version directory.

To work on the pdf package alongside, link a checkout of it in as
`packages/pdf` (git ignores the link here); the packages of this directory
come before a fetched one:

```sh
git clone https://github.com/rschleitzer/pdf ../pdf
ln -s ../../pdf/packages/pdf packages/pdf
```

The program carries its DSSSL prolog and the catalog with the DTDs that read
a stylesheet, so it runs from any directory:

```sh
./dazzle -t sgml -d stylesheet.dsl document.xml
```

(The catalog and the DTDs are laid into `~/.cache/dazzle/` the first time —
the parser reads them as files.)

On Windows the two programs take file names as that system writes them —
backslashes, a drive letter, and `;` between the entries of
`SGML_CATALOG_FILES` and `SGML_SEARCH_PATH` — on the command line and in the
environment, as the original built for Windows does; a batch file written
for `openjade` runs `dazzle` with the same lines.

The C++ reference is built in its own directory: `cd upstream && ./build.sh`.

## Test

```sh
tests/run.sh
```

builds both programs once and runs every suite: the engine's suites compare
its output, backend by backend, with files the C++ reference produced (the
PDF backend's with files of its own, looked at when they were frozen); the
SGML corpus (380 documents) compares the parser's ESIS output with the
reference's; `tests/opensp` runs the parser's unit tests.

## License

The license of the original, see [`LICENSE`](LICENSE): © 1994–1998 James
Clark, © 1999, 2002 the OpenJade Project, © 2026 Ralf Schleitzer for the port
and the modifications.
