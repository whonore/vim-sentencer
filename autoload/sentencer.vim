let s:t_float = type(0.1)

function! s:options() abort
  let l:o = {}
  let l:ignore = g:sentencer_ignore + get(b:, 'sentencer_ignore', [])
  let l:o.punctuation = g:sentencer_ignore == []
    \ ? printf('[%s]\s', g:sentencer_punctuation)
    \ : printf(
      \ '\V\%%(%s\)\@%d<!\[%s]\s',
      \ join(l:ignore, '\|'),
      \ max(map(copy(l:ignore), 'len(v:val)')),
      \ g:sentencer_punctuation
    \)
  let l:o.max_length = g:sentencer_max_length
  let l:o.overflow = type(g:sentencer_overflow) == s:t_float
    \ ? float2nr(round(g:sentencer_overflow * g:sentencer_max_length))
    \ : g:sentencer_overflow
  return l:o
endfunction

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

function! s:nextBreak(line, o) abort
  let l:no_max = a:o.max_length < 0

  " The first punctuation before or at the maximum line length.
  let l:line = l:no_max ? a:line : a:line[:a:o.max_length + a:o.overflow]
  let l:idx = match(l:line, a:o.punctuation)
  if l:idx != -1
    return l:idx
  endif

  " The line is not longer than the maximum line length.
  if l:no_max || len(a:line) <= a:o.max_length + a:o.overflow
    return -1
  endif

  " The last space before or at the maximum line length.
  let l:idx = match(a:line[:a:o.max_length], '.*\zs ')
  if l:idx != -1
    return l:idx
  endif

  " The first space after the maximum line length.
  let l:idx = match(a:line, ' ', a:o.max_length + 1)
  if l:idx != -1
    return l:idx
  endif

  return -1
endfunction

function! s:split(line, o) abort
  let l:lines = []
  let l:line = a:line
  let l:break = 0

  while l:break != -1 && l:line !=# ''
    let l:break = s:nextBreak(l:line, a:o)
    let l:lines = add(l:lines, s:strip(l:line[:l:break]))
    let l:line = s:strip(l:line[l:break + 1:])
  endwhile

  return l:lines
endfunction

function! sentencer#Format() abort
  let l:o = s:options()
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
    let l:lines += map(s:split(s:join(l:para), l:o), 's:indent(v:val, l:indent)')
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
