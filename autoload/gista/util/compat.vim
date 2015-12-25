let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:C = s:V.import('Vim.Compat')

function! gista#util#compat#doautocmd(...) abort
  call call(s:C.doautocmd, a:000, s:C)
endfunction
function! gista#util#compat#getbufvar(...) abort
  return call(s:C.getbufvar, a:000, s:C)
endfunction
function! gista#util#compat#getwinvar(...) abort
  return call(s:C.getwinvar, a:000, s:C)
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
