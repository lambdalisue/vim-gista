"******************************************************************************
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:kind_gist = {
      \ 'name': 'gist',
      \ 'default_action': 'narrow',
      \ 'action_table': {
      \   'narrow': {
      \     'description' : 'narrowing candidates by gist ID',
      \     'is_quit' : 0,
      \     'is_start' : 1,
      \     'is_selectable': 0,
      \   },
      \   'delete': {
      \     'is_selectable': 1,
      \   },
      \   'star': {
      \     'is_selectable': 1,
      \   },
      \   'unstar': {
      \     'is_selectable': 1,
      \   },
      \   'fork': {
      \     'is_selectable': 0,
      \   },
      \ },
      \}

function! s:kind_gist.action_table.narrow.func(candidate) " {{{
  let gist = a:candidate.source__gist
  call unite#mappings#narrowing(gist.id . '#')
endfunction " }}}
function! s:kind_gist.action_table.delete.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#gist#api#delete(gist.id)
  endfor
endfunction " }}}
function! s:kind_gist.action_table.star.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#gist#api#star(gist.id)
  endfor
endfunction " }}}
function! s:kind_gist.action_table.unstar.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#gist#api#unstar(gist.id)
  endfor
endfunction " }}}
function! s:kind_gist.action_table.fork.func(candidate) " {{{
  let gist = a:candidate.source__gist
  call gista#gist#api#fork(gist.id)
endfunction " }}}

function! unite#kinds#gista#define()
  return s:kind_gist
endfunction

" TODO: remove the following codes from production
call unite#define_kind(s:kind_gist)


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
