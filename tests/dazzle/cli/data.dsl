; (data nl) concatenates the descendant data of EVERY member of the node
; list (reference DEFPRIMITIVE(Data): nodeListFirst/nodeListChunkRest loop
; appending nodeData per node into ONE StringObj) — the modules sweep
; caught first-node-only truncation on multi-<return> sprocs.
; Golden validated against the reference dazzle (style-sheet-wrapped copy).
(root (process-children))
(element SUITE
  (let ((tests (select-elements (descendants (current-node)) "TEST")))
    (literal (string-append (data tests) "," (data (children (current-node)))))))
