"******************************************************************************
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:kind = {
      \ 'name': 'gista',
      \ 'default_action': 'open',
      \ 'action_table': {
      \   'open': {
      \     'is_selectable': 1,
      \   },
      \ },
      \}

function! s:kind.action_table.open.func(candidates)
  for candidate in a:candidates
    if has_key(candidate, 'action__filename')
      echomsg candidate.action__gist.description
      echomsg candidate.action__filename
    else
      echomsg candidate.action__gist.description
    endif
  endfor
endfunction

function! unite#kinds#gista#define()
  return s:kind
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
