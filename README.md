# OpenJade (Personal Fork)

This is my personal fork of OpenJade with custom modifications.

## Modifications

- **directory flow object** in TransformFOTBuilder - adds support for directory output organization in SGML/XML transformations

## Directory Flow Object

The `directory` flow object allows creating directory hierarchies during SGML/XML transformations. Files created with the `entity` flow object inside a `directory` are placed in that directory.

```scheme
(declare-flow-object-class directory
  "UNREGISTERED::OpenJade//Flow Object Class::directory")

(make directory path: "output"
  (make directory path: "subdir"
    (make entity system-id: "file.txt"
      (make formatting-instruction data: "content"))))
```

This creates `output/subdir/file.txt` with the content "content".
