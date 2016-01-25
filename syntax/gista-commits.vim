if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gista-commits'

syntax clear
call gista#command#commits#define_highlights()
call gista#command#commits#define_syntax()
