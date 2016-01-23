let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:Validate = s:V.import('Vim.Validate')

function! gista#util#validate#true(...) abort
  call call(s:Validate.true, a:000, s:Validate)
endfunction
function! gista#util#validate#false(...) abort
  call call(s:Validate.false, a:000, s:Validate)
endfunction
function! gista#util#validate#exists(...) abort
  call call(s:Validate.exists, a:000, s:Validate)
endfunction
function! gista#util#validate#not_exists(...) abort
  call call(s:Validate.not_exists, a:000, s:Validate)
endfunction
function! gista#util#validate#key_exists(...) abort
  call call(s:Validate.key_exists, a:000, s:Validate)
endfunction
function! gista#util#validate#key_not_exists(...) abort
  call call(s:Validate.key_not_exists, a:000, s:Validate)
endfunction
function! gista#util#validate#empty(...) abort
  call call(s:Validate.empty, a:000, s:Validate)
endfunction
function! gista#util#validate#not_empty(...) abort
  call call(s:Validate.not_empty, a:000, s:Validate)
endfunction
function! gista#util#validate#pattern(...) abort
  call call(s:Validate.pattern, a:000, s:Validate)
endfunction
function! gista#util#validate#not_pattern(...) abort
  call call(s:Validate.not_pattern, a:000, s:Validate)
endfunction

call s:Validate.set_config({
      \ 'prefix': 'vim-gista: ',
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
