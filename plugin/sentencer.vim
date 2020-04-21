if exists('g:loaded_sentencer')
  finish
endif
let g:loaded_sentencer = 1

let s:filetypes = ['markdown', 'tex', 'text']

augroup sentencer
  autocmd! *
  for s:ft in get(g:, 'sentencer_filetypes', s:filetypes)
    execute printf('autocmd FileType %s setlocal formatexpr=sentencer#Format()', s:ft)
  endfor
augroup END
