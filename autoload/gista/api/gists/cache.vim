let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')

function! s:pick_necessary_params_of_file(content) abort
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
        \   's:pick_necessary_params_of_file(v:val)'
        \ ),
        \ 'created_at': a:gist.created_at,
        \ 'updated_at': a:gist.updated_at,
        \ '_gista_fetched': get(a:gist, '_gista_fetched', 0),
        \ '_gista_modified': get(a:gist, '_gista_modified', 0),
        \}
endfunction

function! gista#api#gists#cache#add_gist(gist) abort
  let client = gista#api#get_current_client()
  call client.gist_cache.set(a:gist.id, a:gist)
endfunction
function! gista#api#gists#cache#remove_gist(gist) abort
  let client = gista#api#get_current_client()
  call client.gist_cache.remove(a:gist.id)
endfunction
function! gista#api#gists#cache#remove_gists(gists) abort
  let client = gista#api#get_current_client()
  call map(copy(a:gists), 'client.gist_cache.remove(v:val.id)')
endfunction

function! gista#api#gists#cache#retrieve_index_entry(gistid, ...) abort
  let options = extend({
        \ 'lookups': [],
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  if empty(options.lookups)
    let username = client.get_authorized_username()
    if !empty(username)
      let options.lookups = [username, username . '/starred', 'public']
    else
      let options.lookups = ['public']
    endif
  endif
  for lookup in filter(uniq(options.lookups), '!empty(v:val)')
    if client.index_cache.has(lookup)
      let index = client.index_cache.get(lookup)
      let entry_ids = map(
            \ copy(index.entries),
            \ 'v:val.id',
            \)
      let found = index(entry_ids, a:gistid)
      if found >= 0
        return index.entries[found]
      endif
    endif
  endfor
  return gista#api#gists#get_pseudo_entry(a:gistid)
endfunction

function! gista#api#gists#cache#add_index_entry(gist, ...) abort
  let options = extend({
        \ 'lookups': [],
        \ 'modified': 0,
        \}, get(a:000, 0, {})
        \)
  if empty(options.lookups)
    let username = gista#api#gists#get_gist_owner(a:gist)
    let options.lookups = [username, 'public']
  endif
  let client = gista#api#get_current_client()
  let entry = s:pick_necessary_params_of_entry(a:gist)
  for lookup in filter(uniq(options.lookups), '!empty(v:val)')
    let index = extend(
          \ gista#api#gists#get_pseudo_index(),
          \ client.index_cache.get(lookup, {})
          \)
    let index.entries = extend([entry], index.entries)
    let index._gista_modified = options.modified
    call client.index_cache.set(lookup, index)
  endfor
endfunction
function! gista#api#gists#cache#update_index_entry(gist, ...) abort
  let options = extend({
        \ 'lookups': [],
        \ 'modified': 0,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  if empty(options.lookups)
    let username = gista#api#gists#get_gist_owner(a:gist)
    let authorized_username = client.get_authorized_username()
    if !empty(authorized_username)
      let options.lookups = [
            \ authorized_username,
            \ authorized_username . '/starred',
            \ username,
            \ 'public'
            \]
    else
      let options.lookups = [username, 'public']
    endif
  endif
  let entry = s:pick_necessary_params_of_entry(a:gist)
  for lookup in filter(uniq(options.lookups), '!empty(v:val)')
    if client.index_cache.has(lookup)
      let index = extend(
            \ gista#api#gists#get_pseudo_index(),
            \ client.index_cache.get(lookup, {})
            \)
      let previous_count = len(index.entries)
      let index.entries = filter(
            \ index.entries,
            \ 'v:val.id != entry.id'
            \)
      if len(index.entries) == previous_count
        " no entry of {gist} found, skip
        continue
      endif
      let index.entries = extend([entry], index.entries)
      let index._gista_modified = options.modified
      call client.index_cache.set(lookup, index)
    endif
  endfor
endfunction
function! gista#api#gists#cache#replace_index_entry(gist, ...) abort
  let options = extend({
        \ 'lookups': [],
        \ 'modified': 0,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  if empty(options.lookups)
    let username = gista#api#gists#get_gist_owner(a:gist)
    let authorized_username = client.get_authorized_username()
    if !empty(authorized_username)
      let options.lookups = [
            \ authorized_username,
            \ authorized_username . '/starred',
            \ username,
            \ 'public'
            \]
    else
      let options.lookups = [username, 'public']
    endif
  endif
  let entry = s:pick_necessary_params_of_entry(a:gist)
  for lookup in filter(uniq(options.lookups), '!empty(v:val)')
    if client.index_cache.has(lookup)
      let index = extend(
            \ gista#api#gists#get_pseudo_index(),
            \ client.index_cache.get(lookup, {})
            \)
      let index.entries = map(
            \ index.entries,
            \ 'v:val.id != entry.id ? v:val : entry'
            \)
      let index._gista_modified = options.modified
      call client.index_cache.set(lookup, index)
    endif
  endfor
endfunction
function! gista#api#gists#cache#remove_index_entry(gist, ...) abort
  let options = extend({
        \ 'lookups': [],
        \ 'modified': 0,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  if empty(options.lookups)
    let username = gista#api#gists#get_gist_owner(a:gist)
    let authorized_username = client.get_authorized_username()
    if !empty(authorized_username)
      let options.lookups = [
            \ authorized_username,
            \ authorized_username . '/starred',
            \ username,
            \ 'public'
            \]
    else
      let options.lookups = [username, 'public']
    endif
  endif
  for lookup in filter(uniq(options.lookups), '!empty(v:val)')
    if client.index_cache.has(lookup)
      let index = extend(
            \ gista#api#gists#get_pseudo_index(),
            \ client.index_cache.get(lookup, {})
            \)
      call filter(
            \ index.entries,
            \ 'v:val.id != a:gist.id'
            \)
      let index._gista_modified = options.modified
      call client.index_cache.set(lookup, index)
    endif
  endfor
endfunction

function! gista#api#gists#cache#update_index_entries(gists, lookup, ...) abort
  let options = extend({
        \ 'fetched': 0,
        \ 'modified': 0,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let entries = map(copy(a:gists), 's:pick_necessary_params_of_entry(v:val)')
  let entry_ids = map(copy(entries), 'v:val.id')
  let index = extend(
        \ gista#api#gists#get_pseudo_index(),
        \ client.index_cache.get(a:lookup, {})
        \)
  let index.entries = filter(
        \ index.entries,
        \ 'index(entry_ids, v:val.id) == -1'
        \)
  let index.entries = extend(entries, index.entries)
  let index._gista_fetched = options.fetched
  let index._gista_modified = options.modified
  call client.index_cache.set(a:lookup, index)
endfunction
function! gista#api#gists#cache#replace_index_entries(gists, lookup, ...) abort
  let options = extend({
        \ 'fetched': 0,
        \ 'modified': 0,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let entries = map(copy(a:gists), 's:pick_necessary_params_of_entry(v:val)')
  let index = extend(
        \ gista#api#gists#get_pseudo_index(),
        \ client.index_cache.get(a:lookup, {})
        \)
  let index.entries = entries
  let index._gista_fetched = options.fetched
  let index._gista_modified = options.modified
  call client.index_cache.set(a:lookup, index)
endfunction

" Resource API
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
  let gist = extend(
        \ gista#api#gists#get_pseudo_gist(a:gistid),
        \ client.gist_cache.get(a:gistid, {})
        \)
  redraw
  return gist
endfunction
function! gista#api#gists#cache#file(gist, filename) abort
  return extend(
        \ gista#api#gists#get_pseudo_gist_file(),
        \ get(a:gist.files, a:filename, {})
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
  let index = extend(
        \ gista#api#gists#get_pseudo_index(),
        \ client.index_cache.get(a:lookup, {})
        \)
  redraw
  return index
endfunction
function! gista#api#gists#cache#patch(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'description': 0,
        \ 'filenames': [],
        \ 'contents': [],
        \ 'cache': 0,
        \}, get(a:000, 0, {})
        \)
  let gist = gista#api#gists#cache#get(a:gistid, options)
  let gist._gista_modified = 1
  let gist.description = type(options.description) == type(0)
        \ ? gist.description
        \ : options.description
  for [filename, content] in s:L.zip(options.filenames, options.contents)
    let gist.files[filename] = extend(
          \ get(gist.files, filename, {}),
          \ content
          \)
  endfor
  if options.cache
    " NOTE:
    " If options.cache is 0, the followings will be performed on
    " gista#api#gists#patch() function later
    if options.verbose
      let client = gista#api#get_current_client()
      redraw
      call gista#util#prompt#echo(printf(
            \ 'Updating a cache of a gist %s in %s ...',
            \ gist.id, client.apiname,
            \))
    endif
    call gista#api#gists#cache#add_gist(gist)
    call gista#api#gists#cache#update_index_entry(gist)
    redraw
  endif
  return gist
endfunction
function! gista#api#gists#cache#delete(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'cache': 0,
        \}, get(a:000, 0, {})
        \)
  let gist = gista#api#gists#cache#get(a:gistid, options)
  if options.cache
    if options.verbose
      let client = gista#api#get_current_client()
      redraw
      call gista#util#prompt#echo(printf(
            \ 'Deleting a cache of a gist %s in %s ...',
            \ gist.id, client.apiname,
            \))
    endif
    call gista#api#gists#cache#remove_gist(gist)
    call gista#api#gists#cache#remove_index_entry(gist)
    redraw
  endif
  return gist
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
