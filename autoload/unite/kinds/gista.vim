"******************************************************************************
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

" Note:
" unite#mappings#narrowing cannot be used because it ADD input
" but I want to replace the input
function! s:narrowing(word, ...) "{{{
  let is_escape = get(a:000, 0, 1)

  setlocal modifiable
  let unite = unite#get_current_unite()

  let unite.input = is_escape ? escape(a:word, ' *') : a:word
  let unite.context.input = unite.input

  call unite#handlers#_on_insert_enter()
  call unite#view#_redraw_prompt()
  call unite#helper#cursor_prompt()
  call unite#view#_bottom_cursor()
  startinsert!
endfunction "}}}


let s:kind_gist = {
      \ 'name': 'gist',
      \ 'default_action': 'narrow',
      \ 'action_table': {
      \   'open': {
      \     'is_selectable': 1,
      \   },
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
      \     'is_selectable': 1,
      \   },
      \   'browse': {
      \     'is_selectable': 1,
      \   },
      \ },
      \}
function! s:kind_gist.action_table.open.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#interface#open(gist.id, '', {
          \ 'openers': {},
          \ 'opener': 'open',
          \})
  endfor
endfunction " }}}
function! s:kind_gist.action_table.narrow.func(candidate) " {{{
  let gist = a:candidate.source__gist
  call s:narrowing(gist.id . '#')
endfunction " }}}
function! s:kind_gist.action_table.delete.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#interface#delete_action(gist.id, {
          \ 'update_list': 0,
          \})
  endfor
endfunction " }}}
function! s:kind_gist.action_table.star.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#interface#star_action(gist.id)
  endfor
endfunction " }}}
function! s:kind_gist.action_table.unstar.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#interface#unstar_action(gist.id)
  endfor
endfunction " }}}
function! s:kind_gist.action_table.fork.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#interface#fork_action(gist.id, {
          \ 'update_list': 0,
          \})
  endfor
endfunction " }}}
function! s:kind_gist.action_table.browse.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    let filename = get(candidate, 'source__filename', '')
    call gista#interface#browse_action(gist.id, filename)
  endfor
endfunction " }}}

let s:kind_gist_file = {
      \ 'name': 'gist_file',
      \ 'default_action': 'open',
      \ 'parents': ['gist', 'openable'],
      \ 'action_table': {
      \   'open': {
      \     'is_selectable': 1,
      \   },
      \   'rename': {
      \     'is_selectable': 0,
      \   },
      \   'remove': {
      \     'is_selectable': 1,
      \   },
      \ },
      \}
function! s:kind_gist_file.action_table.open.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    let filename = candidate.source__filename
    call gista#interface#open(gist.id, filename, {
          \ 'openers': {},
          \ 'opener': 'open',
          \})
  endfor
endfunction " }}}
function! s:kind_gist_file.action_table.rename.func(candidate) " {{{
  let gist = a:candidate.source__gist
  let filename = a:candidate.source__filename
  call gista#interface#rename_action(gist.id, filename, {
        \ 'update_list': 0,
        \})
endfunction " }}}
function! s:kind_gist_file.action_table.remove.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    let filename = candidate.source__filename
    call gista#interface#remove_action(gist.id, filename, {
          \ 'update_list': 0,
          \})
  endfor
endfunction " }}}


function! unite#kinds#gista#define() " {{{
  return [s:kind_gist, s:kind_gist_file]
endfunction " }}}

" TODO: remove the following codes from production
call unite#define_kind(s:kind_gist)
call unite#define_kind(s:kind_gist_file)


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=markervim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
