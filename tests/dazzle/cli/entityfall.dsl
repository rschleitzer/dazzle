; entity flow object with an un-creatable output file: the reference opens
; the file AT startEntity — a failed open reports cannotOpenOutputError
; (`<argv0>:E: cannot open output file "…" (…)`) on stderr, leaves os_ on
; the PARENT stream (the content falls through to stdout) and exits 0.
; Golden validated against the reference dazzle (style-sheet-wrapped copy).
(declare-flow-object-class entity "UNREGISTERED::James Clark//Flow Object Class::entity")
(declare-flow-object-class formatting-instruction "UNREGISTERED::James Clark//Flow Object Class::formatting-instruction")
(root (make entity system-id: "no_such_dir/out.txt"
        (make formatting-instruction data: "FALLBACK")))
