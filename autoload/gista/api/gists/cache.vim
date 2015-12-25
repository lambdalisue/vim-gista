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

function! s:get_pseudo_gist(gistid) abort
  return {
        \ 'id': a:gistid,
        \ 'description': '',
        \ '_gista_fetched': 0,
        \ '_gista_modified': 0,
        \ '_gista_last_modified': '',
        \}
endfunction
function! s:get_pseudo_content(lookup) abort
  return {
        \ 'lookup': a:lookup,
        \ 'entries': [],
        \ '_gista_fetched': 0,
        \ '_gista_modified': 0,
        \ '_gista_last_modified': '',
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
          \ 'Trying to load a gist %s in %s from the local cache ...',
          \ a:gistid, client.apiname,
          \))
  endif
  return extend(
        \ s:get_pseudo_gist(a:gistid),
        \ client.content_cache.get(a:gistid, {})
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
          \ 'Loading gists of %s in %s from the cache ...',
          \ a:lookup, client.apiname,
          \))
  endif
  return extend(
        \ s:get_pseudo_content(a:lookup),
        \ client.entry_cache.get(a:lookup, {})
        \)
endfunction
function! gista#api#gists#cache#patch(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'description': g:gista#api#gists#patch_interactive_description,
        \ 'filenames': [],
        \ 'contents': [],
        \ 'cache': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let gist = gista#api#gists#cache#get(a:gistid, options)

  " Description
  let description = gist.description
  if type(options.description) == type(0)
    if options.description
      let description = gista#util#prompt#ask(
            \ 'Please input a description of a gist: ',
            \ gist.description,
            \)
    endif
  else
    let description = options.description
  endif
  if empty(description) && !g:gista#api#gists#patch_allow_empty_description
    call gista#util#prompt#throw(
          \ 'An empty description is not allowed',
          \ 'See ":help g:gista#api#gists#patch_allow_empty_description" for detail',
          \)
  endif
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
    call client.content_cache.set(gist.id, gist)
    call gista#api#gists#cache#add_entry(gist)
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
    call client.content_cache.remove(gist.id)
    call gista#api#gists#cache#delete_entry(gist)
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

function! gista#api#gists#cache#retrieve_entry(gistid, ...) abort
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
    if client.entry_cache.has(lookup)
      let content = client.entry_cache.get(lookup)
      let entry_ids = map(
            \ copy(content.entries),
            \ 'v:val.id',
            \)
      let found = index(entry_ids, a:gistid)
      if found >= 0
        return content.entries[found]
      endif
    endif
  endfor
  return s:get_pseudo_gist(a:gistid)
endfunction
function! gista#api#gists#cache#add_entry(entry, ...) abort
  let options = extend({
        \ 'lookups': [],
        \ 'modified': 0,
        \ 'replace': 1,
        \}, get(a:000, 0, {})
        \)
  if empty(options.lookups)
    let username = get(get(a:entry, 'owner', {}), 'login', '')
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
    let content = extend(
          \ s:get_pseudo_content(lookup),
          \ client.entry_cache.get(lookup, {})
          \)
    if options.replace
      let content.entries = filter(
            \ content.entries,
            \ 'v:val.id != entry.id'
            \)
    endif
    let content.entries = extend([entry], content.entries)
    let content._gista_modified = options.modified
    call client.entry_cache.set(lookup, content)
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
  let entry_ids = options.replace ? [] : map(copy(entries), 'v:val.id')
  for lookup in options.lookups
    let content = extend(
          \ s:get_pseudo_content(lookup),
          \ client.entry_cache.get(lookup, {})
          \)
    if options.replace
      let content.entries = entries
    else
      let content.entries = filter(
            \ content.entries,
            \ 'index(entry_ids, v:val.id) == -1'
            \)
      let content.entries = extend(entries, content.entries)
    endif
    let content._gista_modified = options.modified
    call client.entry_cache.set(lookup, content)
  endfor
endfunction
function! gista#api#gists#cache#update_entry(entry, ...) abort
  let options = extend({
        \ 'lookups': [],
        \ 'modified': 0,
        \}, get(a:000, 0, {})
        \)
  if empty(options.lookups)
    let username = get(get(a:entry, 'owner', {}), 'login', '')
    if empty(username)
      let options.lookups = ['public']
    else
      let options.lookups = [username, username . '/starred', 'public']
    endif
  endif
  let client = gista#api#get_current_client()
  let entry = s:pick_necessary_params_of_entry(a:entry)
  for lookup in options.lookups
    if client.entry_cache.has(lookup)
      let content = client.entry_cache.get(lookup)
      let content.entries = map(
            \ content.entries,
            \ 'v:val.id != entry.id ? v:val : entry'
            \)
      let content._gista_modified = options.modified
      call client.entry_cache.set(lookup, content)
    endif
  endfor
endfunction
function! gista#api#gists#cache#delete_entry(entry, ...) abort
  let options = extend({
        \ 'lookups': [],
        \ 'modified': 0,
        \}, get(a:000, 0, {})
        \)
  if empty(options.lookups)
    let username = get(get(a:entry, 'owner', {}), 'login', '')
    let options.lookups = filter(
          \ [username, 'public'],
          \ '!empty(v:val)'
          \)
  endif
  let client = gista#api#get_current_client()
  let entry = s:pick_necessary_params_of_entry(a:entry)
  for lookup in options.lookups
    if client.entry_cache.has(lookup)
      let content = client.entry_cache.get(lookup)
      let content.entries = filter(
            \ content.entries,
            \ 'v:val.id != entry.id'
            \)
      let content._gista_modified = options.modified
      call client.entry_cache.set(lookup, content)
    endif
  endfor
endfunction

function! gista#api#gists#cache#delete_contents(entries) abort
  let client = gista#api#get_current_client()
  let content_cache = client.content_cache
  for entry in a:entries
    call content_cache.remove(entry.id)
  endfor
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
