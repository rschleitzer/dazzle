# dazzle

A DSSSL processor: James Clark's OpenSP and OpenJade, ported from C++ to
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

## Build

Install Scaly (`curl -fsSL https://scaly.io/install.sh | sh`, or see
[scaly.io/download](https://scaly.io/download/)) and check out the pdf package
beside this repository — `packages/pdf` here is a link into it:

```sh
git clone https://github.com/rschleitzer/pdf ../pdf
```

Then from this directory:

```sh
scaly build packages/dazzle/0.1.0/programs/dazzle.scaly --release -o dazzle
scaly build packages/opensp/0.1.0/programs/onsgmls.scaly --release -o onsgmls
```

The compiler finds the packages in `packages/` here and the standard
library in the installation. Compiling the engine needs a 64 MB stack
(`ulimit -s 65520`).

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
