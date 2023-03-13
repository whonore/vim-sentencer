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

let s:trim_both = 0
let s:trim_start = 1
let s:trim_end = 2

function! s:trim(...) abort
  let l:txt = a:1
  let l:dir = get(a:000, 1, s:trim_both)
  let l:pat = l:dir == s:trim_both
    \ ? '\%(^\s\+\|\s\+$\)'
    \ : l:dir == s:trim_start
    \ ? '^\s\+'
    \ : '\s\+$'
  return substitute(l:txt, l:pat, '', 'g')
endfunction

function! s:bufempty() abort
  return line('$') == 1 && empty(getline(1))
endfunction

function! s:insertline(start, text) abort
  if s:bufempty()
    " append adds an extra newline if the file is empty
    call setline(a:start, a:text)
  else
    call append(a:start - 1, a:text)
  endif
endfunction

function! s:nearestnonws(line, cidx) abort
  " Find the nearest non-whitespace character to `cidx`, preferring later
  " matches.
  let l:cidx = match(a:line, '\S', a:cidx)
  if l:cidx == -1
    let l:cidx = match(a:line[:a:cidx], '.*\zs\S')
  endif
  " If there are no non-whitespace characters, treat it as a blank line.
  return l:cidx != -1 ? [a:line[l:cidx], l:cidx - a:cidx] : ['', -a:cidx]
endfunction

function! s:matchidx(lines, lidx, cidx, chr) abort
  " Count the number of matches of the character at `(lidx, cidx)` in `lines`
  " up to and including `(lidx, cidx)`.
  let l:pat = !empty(a:chr) ? '\V' . a:chr : '^\s*$'
  let l:idx = 0
  for l:lidx in range(a:lidx + 1)
    let l:line = a:lines[l:lidx]
    let l:cnt = 1
    while 1
      let l:cidx = match(l:line, l:pat, 0, l:cnt)
      if l:cidx == -1
        break
      endif
      let l:cnt += 1
      let l:idx += 1
      if [l:lidx, l:cidx] == [a:lidx, a:cidx]
        return l:idx
      endif
    endwhile
  endfor
  throw printf('Failed to find character (%s)', a:chr)
endfunction

function! s:findidx(lines, idx, chr) abort
  " Find the `idx`-th match of `chr` in `lines.`
  let l:pat = !empty(a:chr) ? '\V' . a:chr : '^$'
  let l:idx = 0
  for l:lidx in range(len(a:lines))
    let l:line = a:lines[l:lidx]
    let l:cnt = 1
    while 1
      let l:cidx = match(l:line, l:pat, 0, l:cnt)
      if l:cidx == -1
        break
      endif
      let l:cnt += 1
      let l:idx += 1
      if l:idx == a:idx
        return [l:lidx, l:cidx]
      endif
    endwhile
  endfor
  throw printf('Failed to find character (%s)', a:chr)
endfunction

function! s:trackcursor(lines, start, end) abort
  let [l:lnum, l:cnum] = getcurpos()[1:2]
  let l:type = l:lnum < a:start ? 'before' : a:end < l:lnum ? 'after' : 'inside'
  let l:curinfo = {
    \ 'type': l:type,
    \ 'cpos': [l:lnum, l:cnum],
    \ 'start': a:start,
    \ 'nlines': a:end - a:start + 1
  \}

  if l:type ==# 'inside'
    " Remember the index of the character under the cursor (how many of the
    " same character appear before it) in order to restore the position after
    " formatting. This is much easier than trying to map the original position
    " to the new position after formatting.
    let l:lidx = l:lnum - a:start
    let l:cidx = l:cnum - 1
    let [l:curchr, l:coff] = s:nearestnonws(a:lines[l:lidx], l:cidx)
    let l:curinfo['curchr'] = l:curchr
    let l:curinfo['curidx'] = s:matchidx(a:lines, l:lidx, l:cidx + l:coff, l:curchr)
    let l:curinfo['curoff'] = l:coff
  endif

  return l:curinfo
endfunction

function! s:restorecursor(lines, curinfo) abort
  if a:curinfo.type ==# 'before'
    " Cursor position is unchanged
    return a:curinfo.cpos
  elseif a:curinfo.type ==# 'after'
    " Cursor line may have changed
    let l:loff = len(a:lines) - a:curinfo.nlines
    return [a:curinfo.cpos[0] + l:loff, a:curinfo.cpos[1]]
  else
    " Restore cursor position by locating the cursor character
    let [l:lidx, l:cidx] = s:findidx(a:lines, a:curinfo.curidx, a:curinfo.curchr)
    let l:cidx = max([l:cidx - a:curinfo.curoff, 0])
    return [l:lidx + a:curinfo.start, l:cidx + 1]
  endif
endfunction

function! s:padtrailing(lines, curinfo, lnum, cnum) abort
  " Pad with trailing spaces if necessary
  if a:curinfo.type ==# 'inside'
    let l:lidx = a:lnum - a:curinfo.start
    if l:lidx <= len(a:lines) && a:cnum > 1 && a:cnum > len(a:lines[l:lidx])
      let a:lines[l:lidx] .= repeat(' ', a:cnum - len(a:lines[l:lidx]) - 1)
    endif
  endif
  return a:lines
endfunction

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
  let l:o.textwidth = g:sentencer_textwidth > 0
    \ ? g:sentencer_textwidth
    \ : g:sentencer_textwidth == 0 && &textwidth > 0
    \ ? &textwidth
    \ : -1
  let l:o.overflow = type(g:sentencer_overflow) == s:t_float
    \ ? float2nr(round(g:sentencer_overflow * g:sentencer_textwidth))
    \ : g:sentencer_overflow
  let l:o.indent2 = stridx(&formatoptions, '2') != -1
  let l:o.list = stridx(&formatoptions, 'n') != -1 ? &formatlistpat : ''
  return l:o
endfunction

function! s:indent(txt, indent) abort
  return repeat(' ', a:indent) . a:txt
endfunction

function! s:paragraphs(lines, o) abort
  " indent-first, indent-rest, insert-blank?, list?, lines
  let l:paras = [[-1, -1, 0, 0, []]]
  for l:line in a:lines
    " Blank line
    if l:line =~# '^\s*$'
      let l:paras = add(l:paras, [-1, -1, 1, 0, []])
    " List
    elseif a:o.list !=# '' && l:line =~# a:o.list
      let l:paras = add(l:paras, [
        \ match(l:line, '\S'),
        \ matchend(l:line, a:o.list),
        \ 0,
        \ 1,
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
      let l:paras[-1][4] = add(l:paras[-1][4], l:line)
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

function! s:nextBreak(line, indent, skip, o) abort
  let l:no_max = a:o.textwidth < 0
  let l:textwidth = max([a:o.textwidth - a:indent, 0])
  let l:line = a:line
  for l:pat in a:o.bound
    let l:line = substitute(l:line, l:pat, '~', 'g')
  endfor

  " The first punctuation before or at the maximum line length. Ignore
  " punctuation that begins a list (e.g., 1.).
  let l:maxline = l:no_max ? l:line : strcharpart(l:line, 0, l:textwidth + a:o.overflow + 1)
  let l:idx = match(l:maxline, a:o.punctuation, a:skip)
  if l:idx != -1
    return l:idx
  endif

  " The line is not longer than the maximum line length.
  if l:no_max || strdisplaywidth(l:line) <= l:textwidth + a:o.overflow
    return -1
  endif

  " The last space before or at the maximum line length.
  let l:idx = match(strcharpart(l:line, 0, l:textwidth + 1), '.*\zs' . a:o.space)
  if l:idx != -1
    return l:idx
  endif

  " The first space after the maximum line length.
  let l:idx = match(l:line, a:o.space, l:textwidth + 1)
  if l:idx != -1
    return l:idx
  endif

  return -1
endfunction

function! s:split(line, indent1, indent, list, o) abort
  let l:lines = []
  let l:line = a:line
  let l:break = 0

  while l:break != -1 && l:line !=# ''
    let l:first = l:break == 0
    let l:skiplist = a:list && l:first
    let l:break = s:nextBreak(
      \ l:line,
      \ l:first ? a:indent1 : a:indent,
      \ l:skiplist ? a:indent : 0,
      \ a:o)
    let l:lines = add(l:lines, s:trim(l:line[:l:break]))
    let l:line = s:trim(l:line[l:break + 1:])
  endwhile

  return l:lines
endfunction

function! s:equptotrailing(lines1, lines2) abort
  " Check if two sets of lines are equal ignoring differences in trailing
  " whitespace.
  let l:len = len(a:lines1)
  if l:len != len(a:lines2)
    return 0
  endif
  for l:idx in range(l:len)
    let l:line1 = a:lines1[l:idx]
    let l:line2 = a:lines2[l:idx]
    if s:trim(l:line1, s:trim_end) != s:trim(l:line2, s:trim_end)
      return 0
    endif
  endfor
  return 1
endfunction

function! sentencer#Format(...) abort
  let l:o = s:options()
  if a:0 " from :Sentencer command
    let l:start = a:1
    let l:end = a:2
  else " from formatexpr
    let l:start = v:lnum
    let l:end = l:start + v:count - 1
  endif
  let l:orig = getline(l:start, l:end)
  let l:curinfo = s:trackcursor(l:orig, l:start, l:end)

  let l:lines = []
  for [l:indent1, l:indent, l:blank, l:list, l:para] in s:paragraphs(l:orig, l:o)
    if l:blank
      let l:lines += ['']
    endif
    if empty(l:para)
      continue
    endif
    let l:para = s:split(s:join(l:para), l:indent1, l:indent, l:list, l:o)
    let l:lines +=
      \ [s:indent(l:para[0], l:indent1)]
      \ + map(l:para[1:], 's:indent(v:val, l:indent)')
  endfor

  if !s:equptotrailing(l:orig, l:lines)
    let [l:clnum, l:ccnum] = s:restorecursor(l:lines, l:curinfo)
    let l:lines = s:padtrailing(l:lines, l:curinfo, l:clnum, l:ccnum)
    call s:deleteline(l:start, l:end)
    call s:insertline(l:start, l:lines)
    call cursor(l:clnum, l:ccnum)
  endif

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
