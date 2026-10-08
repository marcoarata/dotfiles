" =============================================================================
" Filename: autoload/lightline/colorscheme/yadr.vim
" YADR 2027 :: statusline palette (gray mode blocks, single-yellow filename +
" percent, black middle, blue fileinfo). Sampled from the classic YADR
" reference; entry format (lightline convention): [ [guifg, ctermfg], [guibg, ctermbg] ].
" =============================================================================

" =============================================================================
" Filename: autoload/lightline/colorscheme/yadr.vim
" YADR 2027 :: statusline palette.
"
" Visual chain (all modes share the gray block; the MODE label tells them
" apart, not the color):
"   gray mode | gray-on-yellow arrow | black-on-yellow filename | black middle
"   ... blue fileinfo | yellow percent | gray lineinfo.
" It works because lightline paints each / separator with fg=prev-bg and
" bg=next-bg, so adjacent backgrounds must chain: gray -> yellow -> black ->
" blue -> yellow -> black(for lineinfo text block: gray-on-black at the edge).
"
" Pair order is the lightline convention, verified against
" itchyny/lightline.vim flatten():
"   flat = [first.gui, second.gui, first.cterm, second.cterm]
"   :hi group gets guifg=first guibg=second.
" So [ [fg...], [bg...] ]. If a host renders this file inverted (dark mode
" block, yellow-on-black filename), it is NOT loading this file
" (stale checkout/symlink or lightline without :Lazy restore). Check:
"   :echo g:lightline#colorscheme#yadr#palette.normal.left[0]
" must show [['#002b36', ...], ...] flattened to ['#002b36', '#93a1a1', ...].
" =============================================================================

" Named Solarized slots (single yellow, single gray: no tone drift).
let s:ink    = ['#002b36', 234]   " base03: ink on light blocks
let s:black  = ['#000000', 16]    " middle bg, filename ink
let s:gray   = ['#93a1a1', 247]   " base1: mode bg + middle/lineinfo ink
let s:yellow = ['#fefb67', 227]   " filename + percent bg (the only yellow)
let s:blue   = ['#277fbd', 32]    " fileinfo bg
let s:dim    = ['#657b83', 240]   " base00: inactive ink
let s:deep   = ['#073642', 234]   " base02: inactive bg

let s:p = {'normal': {}, 'inactive': {}, 'insert': {}, 'replace': {}, 'visual': {}, 'command': {}, 'tabline': {}}
let s:p.normal.left = [ [ s:ink, s:gray ], [ s:black, s:yellow ] ]
let s:p.normal.right = [ [ s:gray, s:black ], [ s:black, s:yellow ], [ s:black, s:blue ] ]
let s:p.inactive.right = [ [ s:dim, s:deep ], [ s:dim, s:deep ] ]
let s:p.inactive.left =  [ [ s:dim, s:deep ], [ s:dim, s:deep ] ]
let s:p.insert.left = [ [ s:ink, s:gray ], [ s:black, s:yellow ] ]
let s:p.replace.left = [ [ s:ink, s:gray ], [ s:black, s:yellow ] ]
let s:p.visual.left = [ [ s:ink, s:gray ], [ s:black, s:yellow ] ]
let s:p.command.left = [ [ s:ink, s:gray ], [ s:black, s:yellow ] ]
let s:p.normal.middle = [ [ s:gray, s:black ] ]
let s:p.inactive.middle = [ [ s:dim, s:deep ] ]
let s:p.tabline.left = [ [ s:dim, s:deep ] ]
let s:p.tabline.tabsel = [ [ s:ink, s:gray ] ]
let s:p.tabline.middle = [ [ s:dim, s:deep ] ]
let s:p.tabline.right = copy(s:p.tabline.left)
let s:p.normal.error = [ [ s:ink, ['#dc322f', 160] ] ]
let s:p.normal.warning = [ [ s:ink, ['#b58900', 136] ] ]

let g:lightline#colorscheme#yadr#palette = lightline#colorscheme#flatten(s:p)
