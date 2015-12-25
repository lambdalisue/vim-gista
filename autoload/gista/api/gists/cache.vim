let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')

function! s:pick_necessary_params_of_content(content) abort
  return {
        \ 'size': a:content.size,
        \ 'type': a:content.type,
        \ 'language': a:content.language,
        \}
endfunction
function! s:pick_necessary_params_of_entry(gist) abort
  return {
        \ 'id': a:gist.id,
        \ 'description': a:gist.description,
        \ 'public': a:gist.public,
        \ 'files': map(
        \   copy(a:gist.files),
        \   's:pick_necessary_params_of_content(v:val)'
        \ ),
        \ 'created_at': a:gist.created_at,
        \ 'updated_at': a:gist.updated_at,
        \ '_gista_fetched': get(a:gist, '_gista_fetched', 0),
        \ '_gista_modified': get(a:gist, '_gista_modified', 0),
        \}
endfunction

function! s:get_pseudo_entry(gistid) abort
  return {
        \ 'id': a:gistid,
        \ 'description': '',
        \ 'public': 0,
        \ 'files': {},
        \ '_gista_fetched': 0,
        \ '_gista_modified': 0,
        \}
endfunction
function! s:get_pseudo_gist(gistid) abort
  return extend(s:get_pseudo_entry(a:gistid), {
        \ '_gista_last_modified': '',
        \})
endfunction
function! s:get_pseudo_index() abort
  return {
        \ 'entries': [],
        \ '_gista_fetched': 0,
        \}
endfunction

function! gista#api#gists#cache#get(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Loading a gist %s in %s from the local cache ...',
          \ a:gistid, client.apiname,
          \))
  endif
  return extend(
        \ s:get_pseudo_gist(a:gistid),
        \ client.gist_cache.get(a:gistid, {})
        \)
endfunction
function! gista#api#gists#cache#list(lookup, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Loading gists of %s in %s from the local cache ...',
          \ a:lookup, client.apiname,
          \))
  endif
  return extend(
        \ s:get_pseudo_index(),
        \ client.index_cache.get(a:lookup, {})
        \)
endfunction
function! gista#api#gists#cache#patch(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'description': '',
        \ 'filenames': [],
        \ 'contents': [],
        \ 'cache': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let gist   = gista#api#gists#cache#get(a:gistid, options)
  " Update a gist instance
  let gist._gista_modified = 1
  let gist.description = description
  for [filename, content] in s:L.zip(options.filenames, options.contents)
    let gist.files[filename] = content
  endfor
  if options.cache
    " NOTE:
    " If options.cache is 0, the followings will be performed on
    " gista#api#gists#patch() function later
    if options.verbose
      redraw
      call gista#util#prompt#echo(printf(
            \ 'Updating a cache of a gist %s in %s ...',
            \ gist.id, client.apiname,
            \))
    endif
    call client.gist_cache.set(gist.id, gist)
    call gista#api#gists#cache#add_index(gist)
  endif
  return gist
endfunction
function! gista#api#gists#cache#delete(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'cache': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let gist = gista#api#gists#cache#get(a:gistid, options)
  if options.cache
    if options.verbose
      redraw
      call gista#util#prompt#echo(printf(
            \ 'Deleting a cache of a gist %s in %s ...',
            \ gist.id, client.apiname,
            \))
    endif
    call client.gist_cache.remove(gist.id)
    call gista#api#gists#cache#delete_index(gist)
  endif
  return gist
endfunction
function! gista#api#gists#cache#content(gist, filename, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let file = get(a:gist.files, a:filename, {})
  if empty(file)
    call gista#util#prompt#throw(
          \ '404: Not found',
          \ printf(
          \   'A filename "%s" is not found in a gist %s',
          \   a:filename, a:gist.id,
          \ ),
          \)
  endif
  return {
        \ 'filename': a:filename,
        \ 'content': split(file.content, '\r\?\n'),
        \ 'truncated': file.truncated,
        \}
endfunction

function! gista#api#gists#cache#retrieve_index(gistid, ...) abort
  let options = extend({
        \ 'lookups': [],
        \}, get(a:000, 0, {})
        \)
  if empty(options.lookups)
    let username = gista#api#get_current_username()
    if empty(username)
      let options.lookups = ['public']
    else
      let options.lookups = [username, username . '/starred', 'public']
    endif
  endif
  let client = gista#api#get_current_client()
  for lookup in options.lookups
    if client.index_cache.has(lookup)
      let gist = client.index_cache.get(lookup)
      let index_ids = map(
            \ copy(gist.entries),
            \ 'v:val.id',
            \)
      let found = index(index_ids, a:gistid)
      if found >= 0
        return gist.entries[found]
      endif
    endif
  endfor
  return s:get_pseudo_gist(a:gistid)
endfunction
function! gista#api#gists#cache#add_index(index, ...) abort
  let options = extend({
        \ 'lookups': [],
        \ 'modified': 0,
        \ 'replace': 1,
        \}, get(a:000, 0, {})
        \)
  if empty(options.lookups)
    let username = get(get(a:index, 'owner', {}), 'login', '')
    if !empty(username) && options.replace
      let options.lookups = [username, username . '/starred', 'public']
    else
      let options.lookups = filter(
            \ [username, 'public'],
            \ '!empty(v:val)'
            \)
    endif
  endif
  let client = gista#api#get_current_client()
  let entry = s:pick_necessary_params_of_entry(a:entry)
  for lookup in options.lookups
    let gist = extend(
          \ s:get_pseudo_gist(lookup),
          \ client.index_cache.get(lookup, {})
          \)
    if options.replace
      let gist.entries = filter(
            \ gist.entries,
            \ 'v:val.id != index.id'
            \)
    endif
    let gist.entries = extend([index], gist.entries)
    let gist._gista_modified = options.modified
    call client.index_cache.set(lookup, gist)
  endfor
endfunction
function! gista#api#gists#cache#add_entries(entries, ...) abort
  let options = extend({
        \ 'lookups': [],
        \ 'modified': 0,
        \ 'replace': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let entries = map(
        \ copy(a:entries),
        \ 's:pick_necessary_params_of_entry(v:val)'
        \)
  let index_ids = options.replace ? [] : map(copy(entries), 'v:val.id')
  for lookup in options.lookups
    let gist = extend(
          \ s:get_pseudo_gist(lookup),
          \ client.index_cache.get(lookup, {})
          \)
    if options.replace
      let gist.entries = entries
    else
      let gist.entries = filter(
            \ gist.entries,
            \ 'index(index_ids, v:val.id) == -1'
            \)
      let gist.entries = extend(entries, gist.entries)
    endif
    let gist._gista_modified = options.modified
    call client.index_cache.set(lookup, gist)
  endfor
endfunction
function! gista#api#gists#cache#update_index(index, ...) abort
  let options = extend({
        \ 'lookups': [],
        \ 'modified': 0,
        \}, get(a:000, 0, {})
        \)
  if empty(options.lookups)
    let username = get(get(a:index, 'owner', {}), 'login', '')
    if empty(username)
      let options.lookups = ['public']
    else
      let options.lookups = [username, username . '/starred', 'public']
    endif
  endif
  let client = gista#api#get_current_client()
  let entry = s:pick_necessary_params_of_entry(a:entry)
  for lookup in options.lookups
    if client.index_cache.has(lookup)
      let gist = client.index_cache.get(lookup)
      let gist.entries = map(
            \ gist.entries,
            \ 'v:val.id != index.id ? v:val : index'
            \)
      let gist._gista_modified = options.modified
      call client.index_cache.set(lookup, gist)
    endif
  endfor
endfunction
function! gista#api#gists#cache#delete_index(index, ...) abort
  let options = extend({
        \ 'lookups': [],
        \ 'modified': 0,
        \}, get(a:000, 0, {})
        \)
  if empty(options.lookups)
    let username = get(get(a:index, 'owner', {}), 'login', '')
    let options.lookups = filter(
          \ [username, 'public'],
          \ '!empty(v:val)'
          \)
  endif
  let client = gista#api#get_current_client()
  let entry = s:pick_necessary_params_of_entry(a:entry)
  for lookup in options.lookups
    if client.index_cache.has(lookup)
      let gist = client.index_cache.get(lookup)
      let gist.entries = filter(
            \ gist.entries,
            \ 'v:val.id != index.id'
            \)
      let gist._gista_modified = options.modified
      call client.index_cache.set(lookup, gist)
    endif
  endfor
endfunction

function! gista#api#gists#cache#delete_gists(entries) abort
  let client = gista#api#get_current_client()
  let gist_cache = client.gist_cache
  for index in a:entries
    call gist_cache.remove(index.id)
  endfor
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
