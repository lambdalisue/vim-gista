let s:save_cpo = &cpo
set cpo&vim

if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gista-commits'
let s:save_cpo = &cpo
set cpo&vim

syntax clear
call gista#command#commits#define_highlights()
call gista#command#commits#define_syntax()

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
