<!DOCTYPE STYLE-SHEET PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN">
<STYLE-SHEET>
<STYLE-SPECIFICATION ID=main>
<![CDATA[
; online1 - the POSITIVE matrix of the ONLINE family: marginalia and
; multi-mode. marginalia is a bare bracket whose four characteristics are all
; INHERITED ones; multi-mode is the only class in the port whose PORTS are
; decided at run time - its `multi-modes:` list names them, and each named
; mode is replayed in the order the LIST gives, not the order the content
; gives.

(root (make simple-page-sequence (process-children)))

(define (modes) (list '(#f "lazy-principal") 'lz))

(element p
  (make sequence

    ; --- marginalia --------------------------------------------------------
    (make marginalia (literal "marg-plain"))
    (make marginalia
      marginalia-sep: 3pt
      float-out-marginalia?: #t
      marginalia-keep-with-previous?: #t
      marginalia-side: 'start
      (literal "marg-full"))
    (make marginalia (make marginalia (literal "marg-nested")))

    ; --- multi-mode --------------------------------------------------------
    ; no characteristic at all: no ports, no principal mode element - the
    ; content lands directly in <multi-mode>
    (make multi-mode (literal "mm-plain"))

    ; the principal mode alone (#f in the list)
    (make multi-mode multi-modes: '(#f) (literal "mm-principal"))

    ; named modes only. ★The unlabelled content still lands in the enclosing
    ; stream: the reference passes hasPrincipalMode to pushPorts and never
    ; reads it.
    (make multi-mode multi-modes: '(a b)
      (literal "mm-unlabelled")
      (make sequence label: 'b (literal "B"))
      (make sequence label: 'a (literal "A")))

    ; principal + named, and the desc form of both
    (make multi-mode multi-modes: (list (list '#f "pdesc") (list 'x "xdesc") 'y)
      (literal "P")
      (make sequence label: 'y (literal "Y"))
      (make sequence label: 'x (literal "X")))

    ; a mode with NO content at all still gets its element
    (make multi-mode multi-modes: '(#f empty) (literal "only-principal"))

    ; the same name twice: two ports with the same label - the FIRST one wins
    ; for routing, and both elements are emitted
    (make multi-mode multi-modes: '(dup dup)
      (make sequence label: 'dup (literal "D")))

    ; an EMPTY list is a valid characteristic value: no principal, no modes
    (make multi-mode multi-modes: '() (literal "mm-empty"))

    ; a NON-CONSTANT value: the lazy chain rather than the compile-time
    ; prototype
    (make multi-mode multi-modes: (modes)
      (literal "LZP")
      (make sequence label: 'lz (literal "LZ")))

    ; nesting inside the PRINCIPAL stream - the principal flag is a STACK in
    ; the fot backend. (Nesting inside a NAMED MODE crashes the reference; see
    ; online1b.)
    (make multi-mode multi-modes: '(#f outer)
      (literal "OP")
      (make multi-mode multi-modes: '(#f inner)
        (literal "IP")
        (make sequence label: 'inner (literal "IN")))
      (make sequence label: 'outer (literal "OUT")))

    ; the family mixed with the layout composite
    (make marginalia
      (make multi-mode multi-modes: '(m)
        (make side-by-side label: 'm
          (make side-by-side-item (literal "mixed")))))))
]]>
</STYLE-SPECIFICATION>
</STYLE-SHEET>
