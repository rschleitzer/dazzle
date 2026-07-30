(declare-characteristic scroll-title
  "UNREGISTERED::James Clark//Characteristic::scroll-title" "")
(element doc
  (make scroll
    scroll-title: "Doc & Title"
    (process-children)))
(element title
  (make paragraph
    font-size: 18pt
    font-weight: 'bold
    quadding: 'center
    space-before: 12pt
    (process-children)))
(element p
  (make paragraph
    start-indent: 24pt
    end-indent: 6pt
    first-line-start-indent: -12pt
    line-spacing: 14pt
    (make link
      destination: (node-list-address (element-with-id "FIRST"))
      (process-children))))
(element em
  (make sequence
    font-posture: 'italic
    color: (color (color-space "ISO/IEC 10179:1996//Color-Space Family::Device RGB") 1 0 0)
    (process-children)))
