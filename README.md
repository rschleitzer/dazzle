# Dazzle

A custom DSSSL processor based on OpenJade, with bundled OpenSP.

## Quick Install

```bash
# Install dependencies (macOS)
brew install gettext

# Build
./build.sh

# Install to /usr/local
sudo ./install.sh
```

That's it. No environment variables needed - dazzle finds SGML catalogs automatically.

## Modifications

- **directory flow object** in TransformFOTBuilder - adds support for directory output organization in SGML/XML transformations

## Directory Flow Object

The `directory` flow object allows creating directory hierarchies during SGML/XML transformations. Files created with the `entity` flow object inside a `directory` are placed in that directory.

```scheme
(declare-flow-object-class directory
  "UNREGISTERED::Dazzle//Flow Object Class::directory")

(make directory path: "output"
  (make directory path: "subdir"
    (make entity system-id: "file.txt"
      (make formatting-instruction data: "content"))))
```

This creates `output/subdir/file.txt` with the content "content".
