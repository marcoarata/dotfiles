" =============================================================================
" Filename: autoload/lightline/colorscheme/yadr.vim
" YADR 2027 :: statusline palette (per-mode blocks, single-yellow filename +
" percent, black middle, blue fileinfo + lineinfo). Entry format (lightline
" convention): [ [guifg, ctermfg], [guibg, ctermbg] ].
" =============================================================================
"
" Per-mode blocks (label + color tell the mode apart):
"   NORMAL/COMMAND gray #95A4A6 | INSERT green #33CC63 | VISUAL violet #8D43B3,
"   all with smoke text #686868. (REPLACE unspecified: neutral gray.)
" Visual chain: mode-color on yellow | smoke-on-yellow filename | black
" middle ... blue fileinfo | yellow percent | blue lineinfo, all smoke-inked.
" It works because lightline paints each separator with fg=prev-bg and
" bg=next-bg, so adjacent backgrounds must chain:
"   mode -> yellow -> black -> blue -> yellow -> blue.
" Consequences (verified, not tunable per separator): the first separator
" takes the mode color on yellow; the second one is yellow on black; the
" separator between fileinfo(blue) and percent(yellow) is blue on yellow.
" A black-bg variant there would require a black neighbor and break the
" chain, so it is not offered.
"
" Pair order is the lightline convention, verified against
" itchyny/lightline.vim flatten():
"   flat = [first.gui, second.gui, first.cterm, second.cterm]
"   :hi group gets guifg=first guibg=second.
" So [ [fg...], [bg...] ]. Past inversion reports traced to the
" StatusLine row flag, not this file: solarized8 sets reverse on
" StatusLine/StatusLineNC and nvim merges it into every statusline cell
" (SGR 7 in bytes). colorscheme.lua clears it. If a host still renders
" this file inverted, check:
"   :echo g:lightline#colorscheme#yadr#palette.normal.left[0]
" (must show [['#686868', ...], ...] flattened to ['#686868', '#95A4A6', ...])
" and :verbose hi StatusLine (must show no reverse).
" =============================================================================

" Named slots. Text on colored blocks is dark warm gray #686868 (single ink:
" readable on gray/green/violet/yellow/blue alike, no tone drift).
let s:ink    = ['#002b36', 234]   " base03: tabsel + error/warning ink
let s:black  = ['#000000', 16]    " middle bg, fileinfo ink
let s:gray   = ['#93a1a1', 247]   " base1: middle ink
let s:yellow = ['#fefb67', 227]   " filename + percent bg (the only yellow)
let s:blue   = ['#277fbd', 32]    " fileinfo + lineinfo bg
let s:dim    = ['#657b83', 240]   " base00: inactive ink
let s:deep   = ['#073642', 234]   " base02: inactive bg
let s:smoke  = ['#686868', 241]   " block text: mode/filename/percent/lineinfo
let s:modegray   = ['#95A4A6', 109]   " NORMAL + COMMAND bg
let s:modegreen  = ['#33CC63', 77]    " INSERT bg
let s:modeviolet = ['#8D43B3', 97]    " VISUAL bg

let s:p = {'normal': {}, 'inactive': {}, 'insert': {}, 'replace': {}, 'visual': {}, 'command': {}, 'tabline': {}}
let s:p.normal.left = [ [ s:smoke, s:modegray ], [ s:smoke, s:yellow ] ]
let s:p.normal.right = [ [ s:smoke, s:blue ], [ s:smoke, s:yellow ], [ s:black, s:blue ] ]
let s:p.inactive.right = [ [ s:dim, s:deep ], [ s:dim, s:deep ] ]
let s:p.inactive.left =  [ [ s:dim, s:deep ], [ s:dim, s:deep ] ]
let s:p.insert.left = [ [ s:smoke, s:modegreen ], [ s:smoke, s:yellow ] ]
let s:p.replace.left = [ [ s:smoke, s:modegray ], [ s:smoke, s:yellow ] ]
let s:p.visual.left = [ [ s:smoke, s:modeviolet ], [ s:smoke, s:yellow ] ]
let s:p.command.left = [ [ s:smoke, s:modegray ], [ s:smoke, s:yellow ] ]
let s:p.normal.middle = [ [ s:gray, s:black ] ]
let s:p.inactive.middle = [ [ s:dim, s:deep ] ]
let s:p.tabline.left = [ [ s:dim, s:deep ] ]
let s:p.tabline.tabsel = [ [ s:ink, s:gray ] ]
let s:p.tabline.middle = [ [ s:dim, s:deep ] ]
let s:p.tabline.right = copy(s:p.tabline.left)
let s:p.normal.error = [ [ s:ink, ['#dc322f', 160] ] ]
let s:p.normal.warning = [ [ s:ink, ['#b58900', 136] ] ]

let g:lightline#colorscheme#yadr#palette = lightline#colorscheme#flatten(s:p)
