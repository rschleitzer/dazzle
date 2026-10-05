<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<style-sheet>
<style-specification>
<style-specification-body>
(declare-characteristic page-number-format
  "UNREGISTERED::James Clark//Characteristic::page-number-format" "1")
(declare-characteristic page-number-restart?
  "UNREGISTERED::James Clark//Characteristic::page-number-restart?" #f)

(define %body-font% "Times New Roman")
(define %title-font% "Arial")
(define %mono-font% "Courier New")

(define (page-footer)
  (make sequence
    font-family-name: %title-font% font-size: 9pt
    (literal "Page ")
    (page-number-sosofo)))

(define (book-pages format restart content)
  (make simple-page-sequence
    page-width: 210mm page-height: 297mm
    left-margin: 30mm right-margin: 25mm
    top-margin: 30mm bottom-margin: 30mm
    header-margin: 15mm footer-margin: 15mm
    page-number-format: format
    page-number-restart?: restart
    font-family-name: %body-font% font-size: 11pt line-spacing: 14pt
    left-header: (make sequence font-family-name: %title-font% font-size: 9pt
                   font-posture: 'italic (literal "A Small Book"))
    right-header: (make sequence font-family-name: %title-font% font-size: 9pt
                    (literal "dazzle -t pdf"))
    center-footer: (page-footer)
    content))

(define (toc-line nd level)
  (make paragraph
    font-family-name: %title-font% font-size: 10pt line-spacing: 14pt
    font-weight: (if (= level 0) 'bold 'medium)
    start-indent: (* level 8mm)
    space-before: (if (= level 0) 6pt 0pt)
    (with-mode toc (process-node-list (select-elements (children nd) "TITLE")))
    (make leader (literal "."))
    (make sequence (current-node-page-number-sosofo))))

(mode toc
  (element title (process-children)))

(element book
  (make sequence
    (book-pages "i" #f
      (make sequence
        (make paragraph
          font-family-name: %title-font% font-size: 28pt line-spacing: 34pt
          font-weight: 'bold quadding: 'center
          space-before: 60mm space-after: 12mm
          (with-mode toc
            (process-node-list (select-elements (children (current-node)) "TITLE"))))
        (make rule orientation: 'horizontal line-thickness: 1pt
          space-after: 10mm)
        (make paragraph
          font-family-name: %title-font% font-size: 16pt line-spacing: 20pt
          font-weight: 'bold space-after: 6mm break-before: 'page
          keep-with-next?: #t
          (literal "Contents"))
        (let loop ((cs (select-elements (children (current-node)) "CHAP")))
          (if (node-list-empty? cs)
              (empty-sosofo)
              (sosofo-append
                (with-mode tocnode (process-node-list (node-list-first cs)))
                (loop (node-list-rest cs)))))))
    (book-pages "1" #t
      (process-node-list (select-elements (children (current-node)) "CHAP")))))

(mode tocnode
  (element chap
    (make sequence
      (toc-line (current-node) 0)
      (process-node-list (select-elements (children (current-node)) "SECT"))))
  (element sect (toc-line (current-node) 1)))

(element (book title) (empty-sosofo))

(element chap
  (make display-group
    break-before: 'page
    (process-children)))

(element (chap title)
  (make paragraph
    font-family-name: %title-font% font-size: 22pt line-spacing: 28pt
    font-weight: 'bold space-after: 10mm keep-with-next?: #t
    color: (color (color-space "ISO/IEC 10179:1996//Color-Space Family::Device RGB") 0.1 0.2 0.5)
    (process-children)))

(element sect (make display-group space-before: 8mm (process-children)))

(element (sect title)
  (make paragraph
    font-family-name: %title-font% font-size: 14pt line-spacing: 18pt
    font-weight: 'bold space-before: 8mm space-after: 3mm keep-with-next?: #t
    (process-children)))

(element p
  (make paragraph
    quadding: 'justify first-line-start-indent: 5mm
    space-before: 2mm
    (process-children)))

(element em (make sequence font-posture: 'italic (process-children)))

(element list (make display-group space-before: 3mm space-after: 3mm
  start-indent: 10mm (process-children)))

(element item
  (make paragraph
    first-line-start-indent: -6mm
    (make line-field field-width: 6mm
      (literal (number->string (child-number)) "."))
    (process-children)))

(element code
  (make paragraph
    font-family-name: %mono-font% font-size: 9pt line-spacing: 11pt
    lines: 'asis input-whitespace-treatment: 'preserve
    space-before: 4mm space-after: 4mm start-indent: 5mm
    (process-children)))

(element fig
  (make external-graphic
    entity-system-id: "figure.png"
    display?: #t display-alignment: 'center
    max-width: 60mm
    space-before: 4mm space-after: 4mm))

(element tbl
  (make table
    space-before: 4mm space-after: 4mm
    table-border: (make table-border line-thickness: 1pt)
    (make table-column width: 25mm)
    (make table-column width: (table-unit 1))
    (make table-column width: 20mm)
    (make table-part (process-children))))

(element head
  (make table-row label: 'header font-weight: 'bold
    font-family-name: %title-font% font-size: 9pt (process-children)))
(element r (make table-row font-size: 9pt line-spacing: 11pt (process-children)))

(element c
  (make table-cell
    cell-before-row-margin: 1.5mm cell-after-row-margin: 1.5mm
    cell-before-column-margin: 2mm cell-after-column-margin: 2mm
    cell-after-row-border: (make table-border line-thickness: 0.3pt)
    cell-after-column-border: (if (last-sibling?) #f (make table-border line-thickness: 0.3pt))
    cell-background?: (have-ancestor? "HEAD")
    background-color: (color (color-space "ISO/IEC 10179:1996//Color-Space Family::Device RGB") 0.85 0.88 0.95)
    quadding: (if (last-sibling?) 'end 'start)
    (make paragraph (process-children))))
</style-specification-body>
</style-specification>
</style-sheet>
