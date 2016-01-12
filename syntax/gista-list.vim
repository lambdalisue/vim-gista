if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gista-list'
let s:save_cpo = &cpo
set cpo&vim

syntax clear
call gista#command#list#define_highlights()
call gista#command#list#define_syntax()

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
