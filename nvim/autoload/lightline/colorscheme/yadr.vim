" =============================================================================
" Filename: autoload/lightline/colorscheme/yadr.vim
" YADR 2027 :: statusline palette sampled from the classic YADR reference
" (gray-blue mode, yellow filename/percent, black middle, blue location).
" Entry format (lightline convention): [ [guifg, ctermfg], [guibg, ctermbg] ].
" =============================================================================

let s:p = {'normal': {}, 'inactive': {}, 'insert': {}, 'replace': {}, 'visual': {}, 'tabline': {}}
let s:p.normal.left = [ [ ['#002b36', 234], ['#94a4a6', 109] ], [ ['#000000', 16], ['#fefb67', 227] ] ]
let s:p.normal.right = [ [ ['#93a1a1', 247], ['#000000', 16] ], [ ['#000000', 16], ['#fefb67', 227] ], [ ['#000000', 16], ['#277fbd', 32] ] ]
let s:p.inactive.right = [ [ ['#657b83', 240], ['#073642', 234] ], [ ['#657b83', 240], ['#073642', 234] ] ]
let s:p.inactive.left =  [ [ ['#657b83', 240], ['#073642', 234] ], [ ['#657b83', 240], ['#073642', 234] ] ]
let s:p.insert.left = [ [ ['#002b36', 234], ['#859900', 64] ], [ ['#000000', 16], ['#fefb67', 227] ] ]
let s:p.replace.left = [ [ ['#fdf6e3', 230], ['#dc322f', 160] ], [ ['#000000', 16], ['#fefb67', 227] ] ]
let s:p.visual.left = [ [ ['#002b36', 234], ['#d33682', 125] ], [ ['#000000', 16], ['#fefb67', 227] ] ]
let s:p.normal.middle = [ [ ['#93a1a1', 247], ['#000000', 16] ] ]
let s:p.inactive.middle = [ [ ['#657b83', 240], ['#073642', 234] ] ]
let s:p.tabline.left = [ [ ['#657b83', 240], ['#073642', 234] ] ]
let s:p.tabline.tabsel = [ [ ['#002b36', 234], ['#93a1a1', 247] ] ]
let s:p.tabline.middle = [ [ ['#657b83', 240], ['#073642', 234] ] ]
let s:p.tabline.right = copy(s:p.tabline.left)
let s:p.normal.error = [ [ ['#002b36', 234], ['#dc322f', 160] ] ]
let s:p.normal.warning = [ [ ['#002b36', 234], ['#b58900', 136] ] ]

let g:lightline#colorscheme#yadr#palette = lightline#colorscheme#flatten(s:p)
