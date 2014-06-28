"******************************************************************************
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! gista#statusline#components#gistid() abort
  if exists('b:gistinfo')
    return b:gistinfo.gistid
  endif
  return ''
endfunction

function! gista#statusline#components#filename() abort
  if exists('b:gistinfo')
    return b:gistinfo.filename
  endif
  return ''
endfunction

function! gista#statusline#components#gistinfo() abort
  if exists('b:gistinfo')
    return printf("%s:%s", b:gistinfo.gistid, b:gistinfo.filename)
  endif
  return ''
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
