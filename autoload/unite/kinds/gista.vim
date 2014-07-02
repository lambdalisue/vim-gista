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
      \ 'parents': ['openable', 'uri'],
      \ 'default_action': 'smart_open',
      \ 'action_table': {
      \   'open': {
      \     'description': 'open gist files',
      \     'is_selectable': 1,
      \   },
      \   'select': {
      \     'description': 'select gist files',
      \     'is_selectable': 0,
      \     'is_start': 1,
      \   },
      \   'delete': {
      \     'description': 'delete the selected gists',
      \     'is_selectable': 1,
      \   },
      \   'star': {
      \     'description': 'star the selected gists',
      \     'is_selectable': 1,
      \   },
      \   'unstar': {
      \     'description': 'unstar the selected gists',
      \     'is_selectable': 1,
      \   },
      \   'fork': {
      \     'description': 'fork the selected gists',
      \     'is_selectable': 1,
      \   },
      \ },
      \}
function! s:kind.action_table.open.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#interface#open(gist.id, '', {
          \ 'openers': {},
          \ 'opener': 'open',
          \})
  endfor
endfunction " }}}
function! s:kind.action_table.select.func(candidate) " {{{
  let context = {}
  let context.source__gist = a:candidate.source__gist
  call unite#start_script(['gista_file'], context)
endfunction " }}}
function! s:kind.action_table.delete.func(candidates) " {{{
  redraw
  echohl GistaTitle
  echo  'Delete:'
  echohl None
  echo 'Deleting' len(a:candidates) 'gists. The followings will be deleted.'
  for candidate in a:candidates
    echo "-" get(candidate, 'abbr', candidate.word)
  endfor
  echo 'If you really want to delete these gists, type "DELETE".'
  echohl GistaWarning
  echo  'This operation cannot be undone even in Gist web interface.'
  echohl None
  let response = input('type "DELETE" to delete the gist: ')
  if response !=# 'DELETE'
    redraw
    echohl GistaWarning
    echo 'Canceled'
    echohl None
    return
  endif
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#interface#delete_action(gist.id, {
          \ 'confirm': 0,
          \ 'update_list': 0,
          \})
  endfor
endfunction " }}}
function! s:kind.action_table.star.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#interface#star_action(gist.id)
  endfor
endfunction " }}}
function! s:kind.action_table.unstar.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#interface#unstar_action(gist.id)
  endfor
endfunction " }}}
function! s:kind.action_table.fork.func(candidates) " {{{
  for candidate in a:candidates
    let gist = candidate.source__gist
    call gista#interface#fork_action(gist.id, {
          \ 'update_list': 0,
          \})
  endfor
endfunction " }}}
function! s:smart_xxxx(candidate) dict abort " {{{
  let gist = a:candidate.source__gist
  if len(gist.files) <= g:gista#unite_smart_open_threshold
    call unite#take_action(self.__method, a:candidate)
  else
    call unite#take_action('select', a:candidate)
  endif
endfunction " }}}
function! s:assign_smart_xxxx() " {{{
  let openable_methods = {
        \ 'open'         : 'select files or open the file.',
        \ 'tabopen'      : 'select files or open the file in a new tab.',
        \ 'choose'       : 'select files or open the file in a selected window.',
        \ 'tabdrop'      : 'select files or open the file by the ": tab drop" command.',
        \ 'split'        : 'select files or open the file, splitting horizontally.',
        \ 'vsplit'       : 'select files or open the file, splitting vertically.',
        \ 'left'         : 'select files or open the file in the left, splitting vertically.',
        \ 'right'        : 'select files or open the file in the right, splitting vertically.',
        \ 'above'        : 'select files or open the file in the top, splitting horizontally.',
        \ 'below'        : 'select files or open the file in the bottom, splitting horizontally.',
        \ 'persist_open' : 'select files or open the file in alternate window.  unite window isn''t closed.',
        \ 'tabsplit'     : 'select files or open the files and vsplit in a new tab.',
        \}
  for [method, description] in items(openable_methods)
    let name = 'smart_' . method
    let s:kind.action_table[name] = {}
    let s:kind.action_table[name].__method = method
    let s:kind.action_table[name].is_selectable = 0
    let s:kind.action_table[name].description = description
    let s:kind.action_table[name].func = function("<SID>smart_xxxx")
  endfor
endfunction " }}}
call s:assign_smart_xxxx()

function! unite#kinds#gista#define() " {{{
  return s:kind
endfunction " }}}
call unite#define_kind(s:kind)    " required for reloading


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=markervim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
