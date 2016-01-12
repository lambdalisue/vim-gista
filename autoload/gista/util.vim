let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:C = s:V.import('Vim.Compat')

function! gista#util#clip(content) abort
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction

function! gista#util#doautocmd(name) abort
  let expr = printf('User Gista%s', a:name)
  call s:C.doautocmd(expr, 1)
endfunction

function! gista#util#ensure_eol(text) abort
  return a:text =~# '\n$' ? a:text : a:text . "\n"
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
