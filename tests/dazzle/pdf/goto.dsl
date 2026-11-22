<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<style-sheet>
<style-specification>
<style-specification-body>
;; Links within the document: each entry of the contents goes to its
;; section, an address of a node (node-list-address); the PDF names a
;; destination where the section begins and links the entry to it.
(element doc
  (make simple-page-sequence
    page-width: 120mm page-height: 80mm
    left-margin: 10mm right-margin: 10mm top-margin: 10mm bottom-margin: 10mm
    font-family-name: "Helvetica" font-size: 12pt line-spacing: 16pt
    (process-children)))
(element toc
  (make display-group
    (with-mode entry (process-node-list (select-elements (children (parent (current-node))) "sec")))))
(mode entry
  (element sec
    (make paragraph
      (make link destination: (node-list-address (current-node))
        (literal (string-append "Go to " (id)))))))
(element sec (make paragraph break-before: 'page (process-children)))
</style-specification-body>
</style-specification>
</style-sheet>
