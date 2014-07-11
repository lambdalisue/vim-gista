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
      \ 'name': 'gista_file',
      \ 'parents': ['openable', 'uri'],
      \ 'default_action': 'open',
      \ 'action_table': {
      \   'open': {
      \     'is_selectable': 1,
      \   },
      \   'rename': {
      \     'is_selectable': 0,
      \   },
      \   'delete': {
      \     'is_selectable': 1,
      \   },
      \   'yank': {
      \     'description': 'yank a gistid or url',
      \     'is_selectable': 0,
      \   },
      \   'yank_gistid': {
      \     'description': 'yank a gistid',
      \     'is_selectable': 0,
      \   },
      \   'yank_url': {
      \     'description': 'yank a gist url',
      \     'is_selectable': 0,
      \   },
      \ },
      \}
function! s:kind.action_table.open.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    let filename = candidate.source__filename
    call gista#interface#open(gist.id, filename, {
          \ 'openers': {},
          \ 'opener': 'open',
          \})
  endfor
endfunction " }}}
function! s:kind.action_table.rename.func(candidate) " {{{
  let gist = a:candidate.source__gist
  let filename = a:candidate.source__filename
  call gista#interface#rename_action(gist.id, filename, '', {
        \ 'update_list': 0,
        \})
endfunction " }}}
function! s:kind.action_table.delete.func(candidates) " {{{
  redraw
  echohl GistaTitle
  echo  'Remove:'
  echohl None
  echo  'Removing ' len(a:candidates) 'files from the gist. '
  echon 'The followings will be removed.'
  for candidate in a:candidates
    echo "-" candidate.source__gist.id get(candidate, 'abbr', candidate.word)
  endfor
  echo  'This operation cannot be undone within vim-gista interface. '
  echon 'You have to go Gist web interface to revert the file.'
  let response = gista#utils#input_yesno('Are you sure to remove the file')
  if !response
    redraw
    echohl GistaWarning
    echo 'Canceled'
    echohl None
    return
  endif
  for candidate in a:candidates
    let gist = candidate.source__gist
    let filename = candidate.source__filename
    call gista#interface#remove_action(gist.id, filename, {
          \ 'confirm': 0,
          \ 'update_list': 0,
          \})
  endfor
endfunction " }}}
function! s:kind.action_table.yank.func(candidate) " {{{
  let gist = a:candidate.source__gist
  let filename = a:candidate.source__filename
  call gista#interface#yank_action(gist.id, filename)
endfunction " }}}
function! s:kind.action_table.yank_gistid.func(candidate) " {{{
  let gist = a:candidate.source__gist
  let filename = a:candidate.source__filename
  call gista#interface#yank_gistid_action(gist.id, filename)
endfunction " }}}
function! s:kind.action_table.yank_url.func(candidate) " {{{
  let gist = a:candidate.source__gist
  let filename = a:candidate.source__filename
  call gista#interface#yank_url_action(gist.id, filename)
endfunction " }}}


function! unite#kinds#gista_file#define() " {{{
  return s:kind
endfunction " }}}
call unite#define_kind(s:kind)   " required for reloading


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=markervim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
