<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<!-- where the elements with an ID begin (the option locations; Dazzle.Pdf's
     GeneratePdfWithLocations): paragraphs, an element in the middle of a
     line, a group before its first line, an empty element, a paragraph at
     the top of a page, a table, its header row repeated on the next page,
     its rows (between the cells, so at the next cell) and cells -->
(element doc
  (make simple-page-sequence
    page-width: 140mm page-height: 120mm
    left-margin: 20mm right-margin: 20mm top-margin: 15mm bottom-margin: 15mm
    font-family-name: "Times New Roman" font-size: 10pt line-spacing: 12pt
    (process-children)))
(element p (make paragraph space-after: 4pt (process-children)))
(element em (make sequence font-posture: 'italic (process-children)))
(element group (make display-group space-before: 6pt start-indent: 5mm (process-children)))
(element empty (empty-sosofo))
(element table
  (make table table-border: #t space-before: 4pt space-after: 4pt
    (make table-part (process-children))))
(element head (process-children))
(element row
  (if (equal? (gi (parent (current-node))) "head")
      (make table-row label: 'header (process-children))
      (make table-row (process-children))))
(element cell
  (make table-cell
    cell-before-row-margin: 2pt cell-after-row-margin: 2pt
    cell-before-column-margin: 3pt cell-after-column-margin: 3pt
    (if (node-list-empty? (select-elements (children (current-node)) "p"))
        (make paragraph (process-children))
        (process-children))))
