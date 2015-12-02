let s:save_cpo = &cpo
set cpo&vim

function! gista#util#anchor#is_suitable(winnum) abort " {{{
  let bufnum  = winbufnr(a:winnum)
  let buftype = gista#util#compat#getbufvar(bufnum, '&l:buftype')
  let buflisted = gista#util#compat#getbufvar(bufnum, '&l:buflisted')
  if !buflisted || buftype =~# g:gista#util#anchor#unsuitable_buftype_pattern
    return 0
  else
    return 1
  endif
endfunction " }}}
function! gista#util#anchor#find_suitable(winnum) abort " {{{
  " find a suitable window in rightbelow from a previous window
  for winnum in range(a:winnum, winnr('$'))
    if gista#util#anchor#is_suitable(winnum)
      return winnum
    endif
  endfor
  " find a suitable window in leftabove from a previous window
  for winnum in range(1, a:winnum - 1)
    if gista#util#anchor#is_suitable(winnum)
      return winnum
    endif
  endfor
  " no suitable window is found.
  return 0
endfunction " }}}
function! gista#util#anchor#focus() abort " {{{
  " find suitable window from the previous window
  let previous_winnum = winnr('#')
  let suitable_winnum = gista#util#anchor#find_suitable(previous_winnum)
  let suitable_winnum = suitable_winnum == 0
        \ ? previous_winnum
        \ : suitable_winnum
  silent execute printf('keepjumps %dwincmd w', suitable_winnum)
endfunction " }}}

" Configure variables
call gista#define_variables('util#anchor', {
      \ 'unsuitable_buftype_pattern': '^\%(nofile\|quickfix\)$',
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
