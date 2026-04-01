# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dazzle is a modernized, self-contained DSSSL processor forked from OpenJade. It implements the ISO/IEC 10179:1996 DSSSL (Document Style Semantics and Specification Language) standard, processing SGML/XML documents using DSSSL stylesheets into various output formats:
- RTF (Rich Text Format)
- TeX
- MIF (FrameMaker)
- SGML/XML transformations
- HTML+CSS
- FOT (Flow Object Tree as XML)

### What Makes Dazzle Different from OpenJade

1. **Self-contained distribution** - OpenSP 1.5.2 is bundled in `opensp/` and built together with the rest. No external OpenSP dependency needed.

2. **Directory flow object** - A custom DSSSL extension not found in OpenJade. The `directory` flow object in `TransformFOTBuilder` enables hierarchical directory creation during SGML/XML transformation output. Declared as:
   ```scheme
   (declare-flow-object-class directory
     "UNREGISTERED::Dazzle//Flow Object Class::directory")
   ```
   Directories can be nested and combined with `entity` flow objects to organize multi-file output.

3. **Modern compiler support** - C++11 compatibility patches applied automatically during build, cross-platform iconv detection, portable build scripts for macOS and Linux.

4. **CMake build system** - Cross-platform CMake build alongside the legacy autoconf build. Supports MSVC on Windows, GCC/Clang on Linux/macOS, and MinGW.

5. **Binary is named `dazzle`** (not `openjade`).

## Build Commands

### CMake (recommended, cross-platform)

```bash
# Configure and build
cmake -B build
cmake --build build -j4

# Install
cmake --install build --prefix /path/to/install

# Windows (MSVC)
cmake -G "Visual Studio 17 2022" -B build
cmake --build build --config Release
```

Requires Perl (for `msggen.pl` / `instmac.pl` code generation). Builds OpenSP and dazzle together as static libraries.

### Autoconf (Unix only, legacy)

```bash
# Build everything (OpenSP + dazzle)
./build.sh

# Install (default prefix: /usr/local)
./install.sh

# Or with custom prefix
PREFIX=/path/to/install ./install.sh

# Clean
make clean
```

`build.sh` is a two-stage build: it builds OpenSP first, then configures and builds dazzle against it. Parallel builds supported via `JOBS` env var (default 4).

## Running Dazzle

```bash
# Basic usage (outputs FOT by default)
./jade/dazzle -c dsssl/catalog document.sgml

# Specify output type and stylesheet
./jade/dazzle -c dsssl/catalog -t rtf -d stylesheet.dsl document.sgml

# Output types: fot, rtf, tex, sgml, xml, html, mif
```

After installation, SGML catalogs are set up automatically — no manual `SGML_CATALOG_FILES` configuration needed.

## Running Tests

```bash
cd testsuite
make all
```

## Architecture

### Library Structure

- **opensp/** - Bundled OpenSP 1.5.2 SGML parser library (built first by `build.sh`).

- **grove/** - SGML grove library implementing the SGML property set. Provides the `Node` class hierarchy for representing parsed SGML documents as a node tree.

- **spgrove/** - Bridges OpenSP parser events to grove nodes. `GroveBuilder` constructs the grove from parser events; `SdNode` handles SGML declaration nodes.

- **style/** - Core DSSSL engine:
  - `Interpreter` - DSSSL Scheme interpreter with garbage collection (`Collector`)
  - `FOTBuilder` - Abstract base class for flow object tree construction
  - `DssslApp` - Application framework for DSSSL processing
  - `Expression`, `Insn` - Expression parsing and VM instruction compilation
  - `ProcessingMode`, `Pattern` - DSSSL processing mode and pattern matching
  - `ELObj` - Expression language objects (Scheme values)

- **jade/** - Output backends:
  - `RtfFOTBuilder` - RTF output
  - `TeXFOTBuilder` - TeX output (for use with JadeTeX)
  - `HtmlFOTBuilder` - HTML+CSS output
  - `MifFOTBuilder` - FrameMaker MIF output
  - `SgmlFOTBuilder` - SGML/XML transformation output
  - `TransformFOTBuilder` - SGML transformation backend (includes dazzle's `directory` flow object)
  - `jade.cxx` - Main entry point (`JadeApp`)

### Build System

Two build systems coexist (CMake files live alongside autoconf files):

**CMake** (cross-platform):
- `CMakeLists.txt` - Top-level project setup, feature detection, `configure_file()` for `config.h`
- `cmake/config.h.cmake` - Unified config header template (replaces the autoconf two-file config.h chain)
- `cmake/DazzleGenerate.cmake` - Functions wrapping `msggen.pl` and `instmac.pl`
- `cmake/RunRedirect.cmake` - Portable stdout-to-file helper for code gen custom commands
- `opensp/CMakeLists.txt`, `grove/CMakeLists.txt`, etc. - Per-library build definitions
- `build/compat-include/OpenSP/` - Generated forwarding headers so `#include <OpenSP/Foo.h>` works on Windows without symlinks

**Autoconf** (Unix legacy):
- `build.sh` / `install.sh` - Top-level build and install scripts
- `Makefile.comm` - Common definitions
- `Makefile.lib` / `Makefile.prog` - Library and program build rules
- `*/Makefile.sub` - Per-directory source lists

### Code Generation

- `.m4` files produce `_inst.cxx` template instantiation files via `instmac.pl`
- `.msg` files produce `*Messages.h` (and sometimes `.cxx`) via `msggen.pl`
- OpenSP uses `opensp/msggen.pl` with `-l libModule`; dazzle uses `msggen.pl` with `-l jstyleModule`
- Both require Perl

## Commit Policy

Use single-line commit messages only. No extended descriptions, no co-author tags, no generation notices.
