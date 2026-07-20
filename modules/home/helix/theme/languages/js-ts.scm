; inherits: ecma,_typescript,_jsx

; Route JSX tag brackets to @punctuation.special_jsx (themed yellow) so they differ
; from (){}[] which stay on @punctuation.bracket (themed purple).
(jsx_opening_element ["<" ">"] @punctuation.special_jsx)
(jsx_closing_element ["</" ">"] @punctuation.special_jsx)
(jsx_self_closing_element ["<" "/>"] @punctuation.special_jsx)
