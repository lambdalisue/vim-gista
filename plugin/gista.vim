"******************************************************************************
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:Gista(...) " {{{
  return gista#Gista(call("gista#interface#option#parse", a:000))
endfunction " }}}


command! -nargs=? -range=% -bang Gista
      \ :call s:Gista(<q-bang>, [<line1>, <line2>], <f-args>)


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
