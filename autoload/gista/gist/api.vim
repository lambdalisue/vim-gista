"******************************************************************************
" GitHub API module
"
" Plugin developers should use this module to build them own plugins.
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:get_gists() abort " {{{
  if !exists('s:gists')
    let s:gists = {}
  endif
  return s:gists
endfunction " }}}
function! s:get_gist(gistid) abort " {{{
  let gists = s:get_gists()
  if !has_key(gists, a:gistid)
    let gist = gista#gist#api#get(a:gistid, {'nocache': 1})
    if empty(gist)
      return {}
    endif
    let gists[a:gistid] = gist
  endif
  return gists[a:gistid]
endfunction " }}}
function! s:set_gist(gistid, gist) abort " {{{
  let gists = s:get_gists()
  let gists[a:gistid] = a:gist
endfunction " }}}
function! s:get_gist_entries(name) abort " {{{
  if !exists('s:gist_entries_cache_dict')
    if !exists('s:gist_entries_cache_directory')
      let value = g:gista#gist_entries_cache_directory
      let s:gist_entries_cache_directory = fnamemodify(expand(value), ':p')
    endif
    let s:gist_entries_cache_dict = {}
  endif
  if !has_key(s:gist_entries_cache_dict, a:name)
    let s:gist_entries_cache_dict[a:name] = gista#utils#cache#new(
          \ a:name,
          \ s:gist_entries_cache_directory, {
          \   'default': [],
          \})
  endif
  return s:gist_entries_cache_dict[a:name]
endfunction " }}}


" Cache
function! gista#gist#api#remove_gist_from_cache(gistid) abort " {{{
  let cache = s:get_gists()
  if has_key(cache, a:gistid)
    unlet cache[a:gistid]
  endif
endfunction " }}}
function! gista#gist#api#remove_gist_entry_from_cache(gistid, ...) abort " {{{
  let suffixes = ['.all', '.starred', '.public']
  let username = get(a:000, 0, gista#gist#raw#get_authenticated_user())
  let filterstr = printf('v:val.id !=# "%s"', a:gistid)

  redraw | echo "Removing a gist entry from the cache ..."
  for suffix in suffixes
    let cache = s:get_gist_entries(username . suffix)
    for [kind, gists] in items(cache.cached)
      let cache.cached[kind] = filter(copy(gists), filterstr)
    endfor
  endfor
endfunction " }}}


" API
function! gista#gist#api#get(gistid, ...) abort " {{{
  let settings = extend({
        \ 'nocache': 0,
        \}, get(a:000, 0, {}))

  if !settings.nocache
    " use cache (if there is no cache of the gist, s:get_gist call this
    " function with nocache:1 internally)
    return s:get_gist(a:gistid)
  endif

  let res = gista#gist#raw#get(a:gistid, settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 404
    redraw
    echohl GistaWarning
    echo  '404 Gist not found:'
    echohl None
    echo  'It seems the gist (' . a:gistid . ') is deleted.'
    echohl GistaQuestion
    let a = gista#utils#input_yesno(
          \ 'Do you want to remove the gist entry from the cache?')
    echohl None
    if a
      call gista#gist#api#remove_gist_from_cache(a:gistid)
      call gista#gist#api#remove_gist_entry_from_cache(a:gistid)
      redraw | echo printf('%s is removed from the cache.', a:gistid)
    endif
    return {}
  elseif type(res.status) == 0 && res.status != 200
    redraw
    echohl GistaWarning
    echo res.status . ' ' . res.statusText . '. '
    echohl None
    if has_key(res.content, 'message')
      echo 'Message: "' . res.content.message . '"'
    endif
    return {}
  endif
  redraw | echo 'Gist (' . res.content.id . ') is loaded.'
  return res.content
endfunction " }}}
function! gista#gist#api#list(lookup, ...) abort " {{{
  let settings = extend({
        \ 'page': -1,
        \ 'since': '',
        \ 'nocache': 0,
        \}, get(a:000, 0, {}))

  " make sure that the user is logged in
  let username = gista#gist#raw#get_authenticated_user()
  call gista#gist#raw#login(username, {
        \ 'allow_anonymous': 1,
        \})

  " get cache (to update the cache, get the cache even if nocache is 1)
  let is_authenticated = gista#gist#raw#is_authenticated()
  let username = gista#gist#raw#get_authenticated_user()
  if is_authenticated && (a:lookup == username || a:lookup == '')
    let cache = s:get_gist_entries(username . '.all')
  elseif is_authenticated && a:lookup == 'starred'
    let cache = s:get_gist_entries(username . '.starred')
  elseif a:lookup != 'public'
    if empty(a:lookup)
      redraw
      echohl GistaError
      echo 'No lookup username is specified.'
      echohl None
      echo 'You have not logged in your GitHub account thus you have to'
            \ 'specify a GitHub username to lookup.'
      return []
    endif
    let cache = s:get_gist_entries(a:lookup . '.public')
  endif

  if settings.page == -1 && !settings.nocache
    " recursive loading with cache
    if exists('cache') && !empty(cache.last_updated)
      " fetch gists newer than cache last updated
      if empty(settings.since)
        let settings.since = cache.last_updated
      endif
    endif
  endif

  let res = gista#gist#raw#list(a:lookup, settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 200
    let loaded_gists = res.content
    if settings.page == -1 && !settings.nocache && exists('cache')
      let cached_gists = cache.get('gists')
      " remove duplicated gists (keep newly loaded gists)
      if !(empty(cached_gists) || empty(loaded_gists))
        redraw | echo "Removing duplicated gist entries ..."
        for loaded_gist in loaded_gists
          call filter(
                \ cached_gists,
                \ 'loaded_gist.id!=v:val.id')
        endfor
      endif
      let gists = loaded_gists + cached_gists
    else
      let gists = loaded_gists
    endif

    " store gists in cache
    if exists('cache') && settings.page == -1
      call cache.set('gists', gists)
    endif
    redraw | echo len(loaded_gists) 'gist entries are updated.'
    return gists
  elseif type(res.status) == 0 && res.status != 200
    redraw
    echohl GistaWarning
    echo res.status . ' ' . res.statusText . '. '
    echohl None
    if res.status == 404
      echo 'Gists of "' . a:lookup .'" could not be found. '
    endif
  endif
endfunction " }}}
function! gista#gist#api#list_commits(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))

  let res = gista#gist#raw#list_commits(a:gistid, settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 200
    let commits = res.content
    redraw | echo len(commits) 'commits are loaded.'
    return commits
  elseif type(res.status) == 0
    redraw
    echohl GistaError
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to list commits of the gist (' . a:gistid . ').'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! gista#gist#api#list_forks(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))

  let res = gista#gist#raw#list_forks(a:gistid, settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 200
    let forks = res.content
    redraw | echo len(forks) 'forks are loaded.'
    return forks
  elseif type(res.status) == 0
    redraw
    echohl GistaError
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to list forks of the gist (' . a:gistid . ').'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! gista#gist#api#post(filenames, contents, ...) abort " {{{
  let settings = extend({
        \ 'description': '',
        \ 'public': -1,
        \ 'interactive_description':  g:gista#interactive_description,
        \ 'interactive_visibility': g:gista#interactive_visibility,
        \}, get(a:000, 0, {}))

  if settings.interactive_description && empty(settings.description)
    redraw
    echohl GistaTitle
    echo  'Description:'
    echohl None
    echo  'Please write a description of the gist.'
    echo  '(You can suppress this message with setting '
    echon '"let g:gista#interactive_description = 0" in your vimrc.)'
    echohl GistaQuestion
    let settings.description = input('Description: ')
    echohl None
  endif

  if settings.interactive_visibility && settings.public == -1
    redraw
    echohl GistaTitle
    echo  'Visibility:'
    echohl None
    echo  'Please specify a visibility of the gist. '
    echon 'If you want to post a gist as a private gist, type "yes".'
    echo  '(You can suppress this message with setting '
    echon '"let g:gista#interactive_visibility = 0" in your vimrc.)'
    echohl GistaQuestion
    let settings.public = !(gista#utils#input_yesno(
          \ 'Post a gist as a private gist?',
          \ g:gista#post_private ? 'yes' : 'no'))
    echohl None
  endif

  let res = gista#gist#raw#post(a:filenames, a:contents, settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 201
    " save gist
    let gist = res.content
    call s:set_gist(gist.id, gist)
    redraw | echo 'Gist is posted: ' . gist.html_url
    return gist
  elseif type(res.status) == 0
    redraw
    echohl GistaError
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to post the gist'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! gista#gist#api#patch(gistid, filenames, contents, ...) abort " {{{
  let settings = extend({
        \ 'description': '',
        \ 'interactive_description':  g:gista#interactive_description,
        \}, get(a:000, 0, {}))

  " get gist
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return {}
  endif

  if empty(settings.description)
    if settings.interactive_description && empty(gist.description)
      redraw
      echohl GistaTitle
      echo  'Description:'
      echohl None
      echo 'It seems that the gist does not have a description'
            \ 'Thut please write a description of the gist.'
      echo '(You can suppress this message with setting '
            \ '"let g:gista#interactive_description = 0" in your vimrc.)'
      echohl GistaQuestion
      let settings.description = input('Description: ')
      echohl None
    elseif settings.interactive_description == 2
      redraw
      echohl GistaTitle
      echo  'Description:'
      echohl None
      echo 'Please modify a description of the gist.'
      echo '(You can suppress this message with setting '
            \ '"let g:gista#interactive_description = 0 or 1" in your vimrc.)'
      echohl GistaQuestion
      let settings.description = input('Description: ', gist.description)
      echohl None
    endif
  endif

  let res = gista#gist#raw#patch(gist, a:filenames, a:contents, settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 200
    let gist = res.content
    " save gist changes
    call s:set_gist(a:gistid, gist)
    redraw | echo 'Gist is saved: ' . gist.html_url
    return gist
  elseif type(res.status) == 0
    redraw
    echohl GistaError
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to save the gist'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! gista#gist#api#rename(gistid, filename, new_filename, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))

  " get gist
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return {}
  endif

  let new_filename = a:new_filename
  if empty(new_filename)
    redraw
    echohl GistaTitle
    echo  'Rename:'
    echohl None
    echo  'Please input a new filename (hit return without modification to cancel).'
    let new_filename = input(a:filename . ' -> ', a:filename)
    if empty(new_filename) || a:filename ==# new_filename
      redraw
      echohl GistaWarning
      echo 'Canceled'
      echohl None
      return
    endif
  endif

  let res = gista#gist#raw#rename(gist,
        \ [a:filename], [new_filename],
        \ settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 200
    let gist = res.content
    " save gist changes
    call s:set_gist(a:gistid, gist)
    redraw | echo a:filename 'renamed to' new_filename '(' . a:gistid . ')'
    return gist
  elseif type(res.status) == 0
    redraw
    echohl GistaError
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Renaming "' . a:filename . '" has failed.'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! gista#gist#api#remove(gistid, filename, ...) abort " {{{
  let settings = extend({
        \ 'confirm': 1,
        \}, get(a:000, 0, {}))

  " get gist
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return {}
  endif

  if settings.confirm
    redraw
    echohl GistaTitle
    echo  'Remove:'
    echohl None
    echo  'Removing "' . a:filename . '" from the gist. '
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
  endif

  let res = gista#gist#raw#remove(gist, [a:filename], settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 200
    let gist = res.content
    " save gist changes
    call s:set_gist(a:gistid, gist)
    redraw | echo a:filename 'is removed (' . a:gistid . ')'
    return gist
  elseif type(res.status) == 0
    redraw
    echohl GistaError
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Removing "' . a:filename . '" has failed.'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! gista#gist#api#delete(gistid, ...) abort " {{{
  let settings = extend({
        \ 'confirm': 1,
        \}, get(a:000, 0, {}))

  " get gist
  let gist = deepcopy(s:get_gist(a:gistid))
  if empty(gist)
    return {}
  endif

  if settings.confirm
    redraw
    echohl GistaTitle
    echo  'Delete:'
    echohl None
    echo  'Deleting a gist (' . a:gistid . '). '
    echon 'If you really want to delete the gist, type "DELETE".'
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
  endif

  let res = gista#gist#raw#delete(gist, settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 204
    " remove the gist from the cache
    call gista#gist#api#remove_gist_from_cache(a:gistid)
    call gista#gist#api#remove_gist_entry_from_cache(a:gistid)
    redraw | echo a:gistid 'is deleted.'
    return 1
  elseif type(res.status) == 0
    redraw
    echohl GistaError
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Deleting "' . a:gistid . '" has failed.'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! gista#gist#api#star(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))

  let res = gista#gist#raw#star(a:gistid, settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 204
    redraw | echo a:gistid 'is starred.'
    return 1
  elseif type(res.status) == 0
    redraw
    echohl GistaError
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to star the gist (' . a:gistid . ').'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! gista#gist#api#unstar(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))

  let res = gista#gist#raw#unstar(a:gistid, settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 204
    redraw | echo a:gistid 'is unstarred.'
    return 1
  elseif type(res.status) == 0
    redraw
    echohl GistaError
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to unstar the gist (' . a:gistid . ').'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! gista#gist#api#is_starred(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))

  " get gist
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return {}
  endif

  let res = gista#gist#raw#is_starred(a:gistid, settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 204
    return 1
  elseif res.status == 404
    return 0
  elseif type(res.status) == 0
    redraw
    echohl GistaError
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to check if the gist (' . a:gistid . ') is starred.'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! gista#gist#api#fork(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))

  " get gist
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return {}
  endif

  if gist.owner.login == gista#gist#raw#get_authenticated_user()
    redraw
    echohl GistaWarning
    echo 'Unable to fork own gist'
    echohl None
    echo 'You cannot fork your own gist'
    return
  endif

  let res = gista#gist#raw#fork(a:gistid, settings)
  let res = extend({'status': '', 'content': ''}, res)

  if res.status == 201
    let gist = res.content
    redraw | echo a:gistid 'is forked to "' . gist.id . '".'
    return gist
  elseif type(res.status) == 0
    redraw
    echohl GistaError
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to fork the gist (' . a:gistid . ').'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab%t et ai textwidth=0 fdm=marker
