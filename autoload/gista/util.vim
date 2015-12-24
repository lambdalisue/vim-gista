let s:save_cpo = &cpo
set cpo&vim

function! gista#util#clip(content) abort " {{{
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
