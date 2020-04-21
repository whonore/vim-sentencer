if exists('g:loaded_sentencer')
  finish
endif
let g:loaded_sentencer = 1

augroup sentencer
  autocmd! *
  autocmd BufRead,BufNewFile *.tex set formatexpr=sentencer#Format()
augroup END
