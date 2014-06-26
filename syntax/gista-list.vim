"******************************************************************************
" Gista list window
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim


highlight default link GistaTitle     Title
highlight default link GistaError     ErrorMsg
highlight default link GistaWarning   WarningMsg
highlight default link GistaInfo      Comment
highlight default link GistaQuestion  Question

highlight default link GistaGistID      Identifier
highlight default link GistaDescription Title
highlight default link GistaPublic      Statement
highlight default link GistaPrivate     Statement
highlight default link GistaFiles       Special
highlight default link GistaComment     Comment

syntax clear
syntax match GistaGistID  /^\[.*\]/
syntax match GistaFiles   /^-.*/
syntax match GistaComment /^".*/
syntax match GistaComment /@\d\d\d\d-\d\d-\d\d.*$/

let b:current_syntax = "gista-list"


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
