scriptencoding utf-8
let s:t_float = type(0.1)

if exists('*deletebufline')
  function! s:deleteline(first, last) abort
    call deletebufline('%', a:first, a:last)
  endfunction
else
  function! s:deleteline(first, last) abort
    execute printf('silent %d,%ddelete _', a:first, a:last)
  endfunction
endif

if exists('*trim')
  function! s:trim(txt) abort
    return trim(a:txt)
  endfunction
else
  function! s:trim(txt) abort
    return substitute(a:txt, '\%(^\s\+\|\s\+$\)', '', 'g')
  endfunction
endif

function! s:options() abort
  let l:o = {}
  let l:ignore = g:sentencer_ignore + get(b:, 'sentencer_ignore', [])
  let l:o.space = '\s'
  let l:o.bound = keys(get(b:, 'sentencer_bound', {}))
  let l:o.punctuation = g:sentencer_ignore == []
    \ ? printf('[%s]%s', g:sentencer_punctuation, l:o.space)
    \ : printf(
      \ '\V\%%(%s\)\@%d<!\[%s]%s',
      \ join(l:ignore, '\|'),
      \ max(map(copy(l:ignore), 'len(v:val)')),
      \ g:sentencer_punctuation,
      \ l:o.space
    \)
  let l:o.max_length = g:sentencer_max_length > 0
    \ ? g:sentencer_max_length
    \ : g:sentencer_max_length == 0 && &textwidth > 0
    \ ? &textwidth
    \ : -1
  let l:o.overflow = type(g:sentencer_overflow) == s:t_float
    \ ? float2nr(round(g:sentencer_overflow * g:sentencer_max_length))
    \ : g:sentencer_overflow
  let l:o.indent2 = stridx(&formatoptions, '2') != -1
  let l:o.list = stridx(&formatoptions, 'n') != -1 ? &formatlistpat : ''
  return l:o
endfunction

function! s:indent(txt, indent) abort
  return repeat(' ', a:indent) . a:txt
endfunction

function! s:paragraphs(lines, o) abort
  " indent-first, indent-rest, insert-blank?, lines
  let l:paras = [[-1, -1, 0, []]]
  for l:line in a:lines
    " Blank line
    if l:line =~# '^\s*$'
      let l:paras = add(l:paras, [-1, -1, 1, []])
    " List
    elseif a:o.list !=# '' && l:line =~# a:o.list
      let l:paras = add(l:paras, [
        \ match(l:line, '\S'),
        \ matchend(l:line, a:o.list),
        \ 0,
        \ [l:line]
      \])
    " Continue paragraph
    else
      " First line
      if l:paras[-1][0] == -1
        let l:paras[-1][0] = match(l:line, '\S')
      " Second line
      elseif l:paras[-1][1] == -1 && a:o.indent2
        let l:paras[-1][1] = match(l:line, '\S')
      endif
      let l:paras[-1][3] = add(l:paras[-1][3], l:line)
    endif
  endfor

  " indent-rest defaults to indent-first
  for l:para in l:paras
    if l:para[1] == -1
      let l:para[1] = l:para[0]
    endif
  endfor

  return l:paras
endfunction

function! s:join(lines) abort
  return join(map(copy(a:lines), 's:trim(v:val)'), ' ')
endfunction

function! s:nextBreak(line, indent, o) abort
  let l:no_max = a:o.max_length < 0
  let l:max_length = max([a:o.max_length - a:indent, 0])
  let l:line = a:line
  for l:pat in a:o.bound
    let l:line = substitute(l:line, l:pat, '~', 'g')
  endfor

  " The first punctuation before or at the maximum line length.
  let l:maxline = l:no_max ? l:line : l:line[:l:max_length + a:o.overflow]
  let l:idx = match(l:maxline, a:o.punctuation)
  if l:idx != -1
    return l:idx
  endif

  " The line is not longer than the maximum line length.
  if l:no_max || len(l:line) <= l:max_length + a:o.overflow
    return -1
  endif

  " The last space before or at the maximum line length.
  let l:idx = match(l:line[:l:max_length], '.*\zs' . a:o.space)
  if l:idx != -1
    return l:idx
  endif

  " The first space after the maximum line length.
  let l:idx = match(l:line, ' ', l:max_length + 1)
  if l:idx != -1
    return l:idx
  endif

  return -1
endfunction

function! s:split(line, indent1, indent, o) abort
  let l:lines = []
  let l:line = a:line
  let l:break = 0

  while l:break != -1 && l:line !=# ''
    let l:break = s:nextBreak(
      \ l:line,
      \ l:break == 0 || a:indent < 0 ? a:indent1 : a:indent,
      \ a:o)
    let l:lines = add(l:lines, s:trim(l:line[:l:break]))
    let l:line = s:trim(l:line[l:break + 1:])
  endwhile

  return l:lines
endfunction

function! sentencer#Format() abort
  let l:o = s:options()
  let l:pos = getcurpos()
  let l:start = v:lnum
  let l:end = l:start + v:count - 1
  let l:orig = getline(l:start, l:end)

  let l:lines = []
  for [l:indent1, l:indent, l:blank, l:para] in s:paragraphs(l:orig, l:o)
    if l:blank
      let l:lines += ['']
    endif
    let l:para = s:split(s:join(l:para), l:indent1, l:indent, l:o)
    let l:lines +=
      \ [s:indent(l:para[0], l:indent1)]
      \ + map(l:para[1:], 's:indent(v:val, l:indent)')
  endfor

  if l:orig != l:lines
    call s:deleteline(l:start, l:end)
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

function! sentencer#bind(...) abort
  let [l:lnum, l:col] = a:0 == 2 ? [a:1, a:2] : ['.', col('.')]
  let l:line = getline(l:lnum)
  let l:col = match(l:line, '\s', l:col - 1)
  if l:col == -1
    return
  endif

  let l:pre = matchstr(l:line[:l:col], '\k\S*\ze\s*$')
  let l:post = matchstr(l:line[l:col:], '^\s*\zs\S*\k')
  let l:pat = printf('\V\<%s\zs\s\+\ze%s\>', l:pre, l:post)

  let l:bound = get(b:, 'sentencer_bound', {})
  if !has_key(l:bound, l:pat)
    let l:bound[l:pat] = matchadd('Conceal', l:pat, 10, -1, {'conceal': '␣'})
  else
    call matchdelete(l:bound[l:pat])
    unlet l:bound[l:pat]
  endif
  let b:sentencer_bound = l:bound
endfunction
