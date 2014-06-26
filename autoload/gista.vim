"*****************************************************************************
" Gista Interface
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"*****************************************************************************

let s:save_cpo = &cpo
set cpo&vim


function! s:GistaList(options) abort " {{{
  let lookup = a:options.list
  if type(lookup) == 0 " Digit
    unlet lookup
    let lookup = ''
  endif
  let options = extend({
        \ 'nocache': 0,
        \ 'page': -1,
        \}, a:options)
  let options = gista#vital#pick(options, [
        \ 'nocache', 'page',
        \])
  return gista#view#list(lookup, options)
endfunction " }}}
function! s:GistaOpen(options) abort " {{{      
  let gistid = a:options.gistid                 
  let filename = split(a:options.filename, ';') 
  return gista#view#open(gistid, filename, {})  
endfunction " }}}                               
function! s:GistaPost(options) abort " {{{
  let gistid = get(a:options, 'gistid', '')
  let options = extend({
        \ 'anonymous': 0,
        \ 'description': '',
        \ 'public': !g:gista#post_private,
        \}, a:options)
  let options = gista#vital#pick(options, [
        \ 'anonymous', 'description', 'public',
        \])
  if empty(gistid)
    if get(a:options, 'multiple')
      return gista#view#post_all_buffers(options)
    else
      return gista#view#post_buffer(
            \ a:options.__range__[0],
            \ a:options.__range__[1],
            \ options)
    endif
  else
    if has_key(a:options, 'public')
      redraw
      echohl GistaWarning
      echo  'Visibility modification is not supported:'
      echohl None
      echo  'It seems you have specified visibility to existing gist.'
      echo  'Gist API does not provide a way to modify the visibility thus '
      echon 'vim-gista cannot change the visibility (public or private) in '
      echon 'its interface.'
      echo  'Thus if you have specified different visibility, it will be '
      echon 'ignored.'
      echohl GistaQuestion
      call input('Hit enter to continue')
      echohl None
    endif
    return gista#view#save_buffer(
          \ a:options.__range__[0],
          \ a:options.__range__[1],
          \ options)
  endif
endfunction " }}}
function! s:GistaRename(options) abort " {{{
  let gistid = a:options.gistid
  let filename = a:options.filename
  if type(options.rename) == 1
    let options = extend({
          \ 'new_filename': options.rename,
          \}, a:options)
  else
    let options = a:options
  endif
  return gista#view#rename(gistid, filename, options)
endfunction " }}}
function! s:GistaRemove(options) abort " {{{
  let gistid = a:options.gistid
  let filename = a:options.filename
  return gista#view#remove(gistid, filename, a:options)
endfunction " }}}
function! s:GistaDelete(options) abort " {{{
  let gistid = a:options.gistid
  return gista#view#delete(gistid, a:options)
endfunction " }}}
function! s:GistaStar(options) abort " {{{
  let gistid = a:options.gistid
  return gista#view#star(gistid, a:options)
endfunction " }}}
function! s:GistaUnstar(options) abort " {{{
  let gistid = a:options.gistid
  return gista#view#unstar(gistid, a:options)
endfunction " }}}
function! s:GistaIsStarred(options) abort " {{{
  let gistid = a:options.gistid
  return gista#view#is_starred(gistid, a:options)
endfunction " }}}
function! s:GistaFork(options) abort " {{{
  let gistid = a:options.gistid
  return gista#view#is_starred(gistid, a:options)
endfunction " }}}
function! s:GistaBrowse(options) abort " {{{
  let gistid = a:options.gistid
  let filename = get(a:options, 'filename', '')
  return gista#view#browse(gistid, filename, a:options)
endfunction " }}}
function! s:GistaDisconnect(options) abort " {{{
  let gistid = a:options.gistid
  let filename = get(a:options, 'filename', '')
  return gista#view#disconnect(gistid, split(filename, ";"), a:options)
endfunction " }}}

function! gista#Gista(options) abort " {{{
  if empty(a:options)
    " validation failed.
    return
  endif
  if !empty(get(a:options, 'list'))
    return s:GistaList(a:options)
  elseif get(a:options, 'open')
    return s:GistaOpen(a:options)
  elseif get(a:options, 'post')
    return s:GistaPost(a:options)
  elseif get(a:options, 'rename')
    return s:GistaRename(a:options)
  elseif get(a:options, 'remove')
    return s:GistaRemove(a:options)
  elseif get(a:options, 'delete')
    return s:GistaDelete(a:options)
  elseif get(a:options, 'star')
    return s:GistaStar(a:options)
  elseif get(a:options, 'unstar')
    return s:GistaUnstar(a:options)
  elseif get(a:options, 'is-starred')
    return s:GistaIsStarred(a:options)
  elseif get(a:options, 'fork')
    return s:GistaFork(a:options)
  elseif get(a:options, 'browse')
    return s:GistaBrowse(a:options)
  elseif get(a:options, 'disconnect')
    return s:GistaDisconnect(a:options)
  endif
endfunction " }}}


let s:settings = {
      \ 'directory': printf('"%s"', fnamemodify(expand('~/.gista/'), ':p')),
      \ 'gist_default_filename': '"gist-file"',
      \ 'gist_api_url': printf('"%s"', get(g:, 'gist_api_url', 'https://gist.github.com')),
      \ 'tokens_directory': -1,
      \ 'gists_cache_directory': -1,
      \ 'private_mark': '"<private>"',
      \ 'public_mark': '""',
      \ 'list_opener': '"topleft 20 split +set\\ winfixheight"',
      \ 'gist_opener': '"rightbelow vsplit"',
      \ 'gist_opener_in_action': -1,
      \ 'close_list_after_open': 0,
      \ 'auto_connect_after_post': 1,
      \ 'update_on_write': 2,
      \ 'enable_default_keymaps': 1,
      \ 'post_private': 0,
      \ 'interactive_description': 1,
      \ 'interactive_publish_status': 1,
      \ 'include_invisible_buffers_in_multiple': 0,
      \}
function! s:init() " {{{
  for [key, value] in items(s:settings)
    if !exists('g:gista#' . key)
      execute 'let g:gista#' . key . ' = ' . value
    endif
  endfor
  " define default values
  if type(g:gista#tokens_directory) == 0
    unlet g:gista#tokens_directory
    let g:gista#tokens_directory = g:gista#directory . 'tokens/'
  endif
  if type(g:gista#gists_cache_directory) == 0
    unlet g:gista#gists_cache_directory
    let g:gista#gists_cache_directory = g:gista#directory . 'gists/'
  endif
  if type(g:gista#gist_opener_in_action) == 0
    unlet g:gista#gist_opener_in_action
    let g:gista#gist_opener_in_action = g:gista#gist_opener
  endif
endfunction
call s:init()
" }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
