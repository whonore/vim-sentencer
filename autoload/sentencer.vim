let s:puncts = '.!?'
let s:punct_pat = '[%s]\s'
let s:maxlen = 80
let s:over = s:maxlen / 10

function! s:indent(txt, indent) abort
  return repeat(' ', a:indent) . a:txt
endfunction

function! s:strip(txt) abort
  return substitute(a:txt, '\%(^\s\+\|\s\+$\)', '', 'g')
endfunction

" TODO: keep blank lines
function! s:join(lines) abort
  return join(map(copy(a:lines), 's:strip(v:val)'), ' ')
endfunction

" TODO: ignore abbreviations, numbered lists?
function! s:nextBreak(line) abort
  let l:puncts = printf(s:punct_pat, get(g:, 'sentencer_punctuation', s:puncts))
  let l:maxlen = get(g:, 'sentencer_max_length', s:maxlen)
  let l:over = get(g:, 'sentencer_overflow', s:over)

  let l:idx = match(a:line, l:puncts)
  if l:idx != -1 && l:idx < l:maxlen - 1
    return l:idx
  endif

  if len(a:line) < l:maxlen + l:over
    return -1
  endif

  let l:idx = strridx(a:line, ' ', l:maxlen - 1)
  if l:idx != -1
    return l:idx
  endif

  return -1
endfunction

function! s:split(line) abort
  let l:lines = []
  let l:line = a:line
  let l:break = 0

  while l:break != -1 && l:line !=# ''
    let l:break = s:nextBreak(l:line)
    let l:lines = add(l:lines, s:strip(l:line[:l:break]))
    let l:line = s:strip(l:line[l:break + 1:])
  endwhile

  return l:lines
endfunction

function! sentencer#Format() abort
  let l:pos = getcurpos()
  let l:start = v:lnum
  let l:end = l:start + v:count - 1
  let l:lines = getline(l:start, l:end)
  let l:indent = indent(l:start)

  let l:joined = s:join(l:lines)
  let l:split = map(s:split(l:joined), 's:indent(v:val, l:indent)')

  execute printf('%d,%ddelete _', l:start, l:end)
  call append(l:start - 1, l:split)

  call setpos('.', l:pos)
  return 0
endfunction
