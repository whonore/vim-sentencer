let s:puncts = '.!?'
let s:punct_pat = '[%s]\s'
let s:maxlen = 0 < &textwidth ? &textwidth : 80

function! s:indent(txt, indent) abort
  return repeat(' ', a:indent) . a:txt
endfunction

function! s:strip(txt) abort
  return substitute(a:txt, '\%(^\s\+\|\s\+$\)', '', 'g')
endfunction

function! s:paragraphs(lines) abort
  let l:paras = [[]]
  for l:line in a:lines
    if l:line =~# '^\s*$'
      let l:paras = add(l:paras, [])
    else
      let l:paras[-1] = add(l:paras[-1], l:line)
    endif
  endfor
  return l:paras
endfunction

function! s:join(lines) abort
  return join(map(copy(a:lines), 's:strip(v:val)'), ' ')
endfunction

" TODO: ignore abbreviations, numbered lists?
function! s:nextBreak(line, opts) abort
  let l:puncts = a:opts['puncts']
  let l:maxlen = a:opts['maxlen']
  let l:over = a:opts['over']

  " Look for punctuation before the maximum line length.
  let l:idx = match(a:line, l:puncts)
  if l:idx != -1 && (l:maxlen == -1 || l:idx < l:maxlen + l:over - 1)
    return l:idx
  endif

  " The line is shorter than the maximum line length.
  if l:maxlen == -1 || len(a:line) < l:maxlen + l:over
    return -1
  endif

  " Look for the last space before the maximum line length.
  let l:idx = strridx(a:line, ' ', l:maxlen - 1)
  if l:idx != -1
    return l:idx
  endif

  return -1
endfunction

function! s:split(line, opts) abort
  let l:lines = []
  let l:line = a:line
  let l:break = 0

  while l:break != -1 && l:line !=# ''
    let l:break = s:nextBreak(l:line, a:opts)
    let l:lines = add(l:lines, s:strip(l:line[:l:break]))
    let l:line = s:strip(l:line[l:break + 1:])
  endwhile

  return l:lines
endfunction

function! sentencer#Format() abort
  let l:opts = {}
  let l:puncts = get(g:, 'sentencer_punctuation', s:puncts)
  let l:opts['puncts'] = printf(s:punct_pat, l:puncts)
  let l:opts['maxlen'] = get(g:, 'sentencer_max_length', s:maxlen)
  let l:opts['over'] = get(g:, 'sentencer_overflow', l:opts['maxlen'] / 10)

  let l:pos = getcurpos()
  let l:start = v:lnum
  let l:end = l:start + v:count - 1
  let l:orig = getline(l:start, l:end)
  let l:indent = indent(l:start)

  let l:first = 1
  let l:lines = []
  for l:para in s:paragraphs(l:orig)
    if !l:first
      let l:lines += ['']
    endif
    let l:lines += map(s:split(s:join(l:para), l:opts), 's:indent(v:val, l:indent)')
    let l:first = 0
  endfor

  if l:orig != l:lines
    execute printf('silent %d,%ddelete _', l:start, l:end)
    if line('$') != 1
      call append(l:start - 1, l:lines)
    else
      " append adds an extra newline if the file is empty
      call setline(l:start, l:lines)
    endif
  endif

  call setpos('.', l:pos)
  return 0
endfunction
