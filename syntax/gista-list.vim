if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gista-list'

syntax clear
call gista#command#list#define_highlights()
call gista#command#list#define_syntax()
