# dazzle

A DSSSL processor: James Clark's OpenSP and OpenJade, ported from C++ to
[Scaly](https://scaly.io).

DSSSL (ISO/IEC 10179) is the style and transformation language of SGML. An
engine reads an SGML or XML document, applies a stylesheet written in a Scheme
dialect, and writes the result through a backend. This repository holds the
whole chain twice:

- `packages/opensp` — the SGML parser, with the program `onsgmls`;
  `packages/dazzle` — the style engine, with the program `dazzle`. Both are
  written in Scaly, a language with region-based memory management the
  compiler infers.
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
fields, leaders, rules, external graphics (JPEG, PNG) and tables, in the
standard fonts Helvetica, Times and Courier — enough to set a book with the
DocBook print stylesheets, and not more. A character outside Windows code
page 1252 prints as `?`.

```sh
SCALY_HOME=$PWD ./dazzle -t pdf -o book.pdf -d stylesheet.dsl document.xml
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
scaly build packages/dazzle/0.1.0/dazzle_cli.scaly --release -o dazzle
scaly build packages/opensp/0.1.0/onsgmls.scaly --release -o onsgmls
```

The compiler finds the packages in `packages/` here and the standard
library in the installation. Compiling the engine needs a 64 MB stack
(`ulimit -s 65520`).

The engine reads its DSSSL prolog and catalog from
`packages/dazzle/0.1.0/dsssl/` under `SCALY_HOME`, so run it with that
variable naming this checkout:

```sh
SCALY_HOME=$PWD ./dazzle -t sgml -d stylesheet.dsl document.xml
```

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
