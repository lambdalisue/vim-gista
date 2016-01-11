let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')
let s:D = s:V.import('Data.Dict')
let s:J = s:V.import('Web.JSON')
let s:G = s:V.import('Web.API.GitHub')

let s:CACHE_DISABLED = 0
let s:CACHE_ENABLED = 1
let s:CACHE_FORCED = 2

function! s:pick_necessary_params_of_index_entry_file(content) abort
  return {
        \ 'size': a:content.size,
        \ 'type': a:content.type,
        \ 'language': a:content.language,
        \}
endfunction
function! s:pick_necessary_params_of_index_entry(gist) abort
  return {
        \ 'id': a:gist.id,
        \ 'description': a:gist.description,
        \ 'public': a:gist.public,
        \ 'files': map(
        \   copy(a:gist.files),
        \   's:pick_necessary_params_of_index_entry_file(v:val)'
        \ ),
        \ 'created_at': a:gist.created_at,
        \ 'updated_at': a:gist.updated_at,
        \ '_gista_fetched': get(a:gist, '_gista_fetched', 0),
        \}
endfunction

function! s:add_gist_cache(client, gist) abort
  call a:client.gist_cache.set(a:gist.id, a:gist)
endfunction
function! s:remove_gist_cache(client, gist) abort
  call a:client.gist_cache.remove(a:gist.id)
endfunction
function! s:remove_gists_cache(client, gists) abort
  call map(copy(a:gists), 's:remove_gist_cache(a:client, v:val)')
endfunction

function! s:add_entry_cache(client, gist, lookups) abort
  let entry = s:pick_necessary_params_of_index_entry(a:gist)
  for lookup in filter(uniq(a:lookups), '!empty(v:val)')
    let index = extend(
          \ gista#resource#gists#get_pseudo_index(),
          \ a:client.index_cache.get(lookup, {})
          \)
    let index.entries = filter(
          \ index.entries,
          \ 'v:val.id !=# a:gist.id'
          \)
    let index.entries = extend([entry], index.entries)
    call a:client.index_cache.set(lookup, index)
  endfor
endfunction
function! s:update_entry_cache(client, gist, lookups) abort
  let entry = s:pick_necessary_params_of_index_entry(a:gist)
  for lookup in filter(uniq(a:lookups), '!empty(v:val)')
    if a:client.index_cache.has(lookup)
      let index = extend(
            \ gista#resource#gists#get_pseudo_index(),
            \ a:client.index_cache.get(lookup, {})
            \)
      let previous_count = len(index.entries)
      call filter(
            \ index.entries,
            \ 'v:val.id !=# entry.id'
            \)
      if len(index.entries) == previous_count
        " no entry of {gist} found, skip
        continue
      endif
      call insert(index.entries, entry, 0)
      call a:client.index_cache.set(lookup, index)
    endif
  endfor
endfunction
function! s:replace_entry_cache(client, gist, lookups) abort
  let entry = s:pick_necessary_params_of_index_entry(a:gist)
  for lookup in filter(uniq(a:lookups), '!empty(v:val)')
    if a:client.index_cache.has(lookup)
      let index = extend(
            \ gista#resource#gists#get_pseudo_index(),
            \ a:client.index_cache.get(lookup, {})
            \)
      let index.entries = map(
            \ index.entries,
            \ 'v:val.id !=# entry.id ? v:val : entry'
            \)
      call a:client.index_cache.set(lookup, index)
    endif
  endfor
endfunction
function! s:remove_entry_cache(client, gist, lookups) abort
  for lookup in filter(uniq(a:lookups), '!empty(v:val)')
    if a:client.index_cache.has(lookup)
      let index = extend(
            \ gista#resource#gists#get_pseudo_index(),
            \ a:client.index_cache.get(lookup, {})
            \)
      let index.entries = filter(
            \ index.entries,
            \ 'v:val.id !=# a:gist.id'
            \)
      call a:client.index_cache.set(lookup, index)
    endif
  endfor
endfunction
function! s:retrieve_entry_cache(client, gistid, lookups) abort
  for lookup in filter(uniq(a:lookups), '!empty(v:val)')
    if a:client.index_cache.has(lookup)
      let index = a:client.index_cache.get(lookup)
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
endfunction

function! s:update_entries_cache(client, gists, lookup) abort
  let entries = map(
        \ copy(a:gists),
        \ 's:pick_necessary_params_of_index_entry(v:val)'
        \)
  let entry_ids = map(copy(entries), 'v:val.id')
  let index = extend(
        \ gista#resource#gists#get_pseudo_index(),
        \ a:client.index_cache.get(a:lookup, {})
        \)
  call filter(
        \ index.entries,
        \ 'index(entry_ids, v:val.id) == -1'
        \)
  call extend(index.entries, entries, 0)
  let index._gista_fetched = 1
  call a:client.index_cache.set(a:lookup, index)
  return index
endfunction
function! s:replace_entries_cache(client, gists, lookup) abort
  let entries = map(
        \ copy(a:gists),
        \ 's:pick_necessary_params_of_index_entry(v:val)'
        \)
  let index = extend(
        \ gista#resource#gists#get_pseudo_index(),
        \ a:client.index_cache.get(a:lookup, {})
        \)
  let index.entries = entries
  let index._gista_fetched = 1
  call a:client.index_cache.set(a:lookup, index)
  return index
endfunction

function! gista#resource#gists#get_gist_owner(gist) abort
  return get(get(a:gist, 'owner', {}), 'login', '')
endfunction
function! gista#resource#gists#get_pseudo_index() abort
  return {
        \ 'entries': [],
        \ '_gista_fetched': 0,
        \}
endfunction
function! gista#resource#gists#get_pseudo_index_entry(gistid) abort
  return {
        \ 'id': a:gistid,
        \ 'description': '',
        \ 'public': 0,
        \ 'files': {},
        \ 'created_at': '',
        \ 'updated_at': '',
        \ '_gista_fetched': 0,
        \}
endfunction
function! gista#resource#gists#get_pseudo_index_entry_file() abort
  return {
        \ 'size': 0,
        \ 'type': '',
        \ 'language': '',
        \}
endfunction
function! gista#resource#gists#get_pseudo_gist(gistid) abort
  return extend(gista#resource#gists#get_pseudo_index_entry(a:gistid), {
        \ '_gista_last_modified': '',
        \})
endfunction
function! gista#resource#gists#get_pseudo_gist_file() abort
  return extend(gista#resource#gists#get_pseudo_index_entry_file(), {
        \ 'truncated': 1,
        \ 'content': '',
        \ 'raw_url': '',
        \})
endfunction

function! gista#resource#gists#get(gistid, ...) abort
  let options = extend({
        \ 'cache': s:CACHE_ENABLED,
        \}, get(a:000, 0, {})
        \)
  " From Cache
  let client = gista#client#get()
  let username = client.get_authorized_username()
  redraw | call gista#util#prompt#echo(printf(
        \ 'Loading a gist %s in %s from a local cache ...',
        \ a:gistid, client.apiname,
        \))
  let gist = extend(
        \ gista#resource#gists#get_pseudo_gist(a:gistid),
        \ client.gist_cache.get(a:gistid, {})
        \)
  redraw
  if options.cache == s:CACHE_FORCED ||
        \ (options.cache != s:CACHE_DISABLED && gist._gista_fetched)
    return extend(copy(gist), {
          \ '_gista_modified': 0,
          \})
  endif
  " From API
  redraw | call gista#util#prompt#echo(printf(
        \ 'Fetching a gist %s in %s ...',
        \ a:gistid, client.apiname,
        \))
  " NOTE:
  let url = 'gists/' . a:gistid
  let res = client.get(url, {}, {
        \ 'If-Modified-Since': gist._gista_last_modified,
        \})
  redraw
  if res.status == 304
    " the content is not modified since the last request
    return extend(copy(gist), {
          \ '_gista_modified': 0,
          \})
  elseif res.status == 200
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:J.decode(res.content)
    let fetched_gist = res.content
    let fetched_gist._gista_fetched = 1
    let fetched_gist._gista_last_modified = s:G.parse_response_last_modified(res)
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Updating caches of a gist %s in %s ...',
          \ a:gistid, client.apiname,
          \))
    call s:add_gist_cache(client, fetched_gist)
    call s:replace_entry_cache(client, fetched_gist, [
          \ gista#resource#gists#get_gist_owner(fetched_gist),
          \ username,
          \ empty(username) ? '' : username . '/starred',
          \ 'public',
          \])
    redraw
    " NOTE:
    " updated_at after PATCH sometime differ from GET thus check difference
    " betweeh cached and fetched except updated_at/_gista_last_modified
    return extend(copy(fetched_gist), {
          \ '_gista_modified': gista#resource#gists#is_modified(
          \   gist, fetched_gist
          \ ),
          \})
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#gists#file(gistid, filename, ...) abort
  let options = extend({
        \ 'cache': s:CACHE_ENABLED,
        \}, get(a:000, 0, {})
        \)
  let gist = gista#resource#gists#get(a:gistid, options)
  let file = extend(
        \ gista#resource#gists#get_pseudo_gist_file(),
        \ get(gist.files, a:filename, {})
        \)
  if options.cache == s:CACHE_FORCED ||
        \ (options.cache != s:CACHE_DISABLED && !file.truncated)
    return file
  endif
  " From API
  let client = gista#client#get()
  let res = client.get(file.raw_url)
  if res.status == 200
    let file.truncated = 0
    let file.content = res.content
    let gist.files[a:filename] = file
    call s:add_gist_cache(client, gist)
    return file
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#gists#list(lookup, ...) abort
  let options = extend({
        \ 'cache': s:CACHE_ENABLED,
        \ 'since': 1,
        \ 'python': has('python') || has('python3'),
        \}, get(a:000, 0, {})
        \)
  " From Cache
  let client = gista#client#get()
  let username = client.get_authorized_username()
  redraw | call gista#util#prompt#echo(printf(
        \ 'Loading gists of %s in %s from a local cache ...',
        \ a:lookup, client.apiname,
        \))
  let index = extend(
        \ gista#resource#gists#get_pseudo_index(),
        \ client.index_cache.get(a:lookup, {})
        \)
  redraw
  if options.cache == s:CACHE_FORCED ||
        \ (options.cache != s:CACHE_DISABLED && index._gista_fetched)
    return index
  endif
  " From API
  let since = type(options.since) == type(0)
        \ ? options.since
        \   ? empty(index.entries)
        \     ? ''
        \     : index.entries[0].updated_at
        \   : ''
        \ : options.since
  if a:lookup ==# 'public'
    let url = 'gists/public'
  elseif !empty(username) && a:lookup ==# username
    let url = 'gists'
  elseif !empty(username) && a:lookup ==# username . '/starred'
    let url = 'gists/starred'
  elseif !empty(a:lookup)
    let url = printf('users/%s/gists', a:lookup)
  else
    call gista#util#prompt#throw(printf(
          \ 'Unknown lookup "%s" is specified',
          \ a:lookup,
          \))
  endif
  let indicator = printf(
        \ 'Requesting gists of %s in %s %%%%(page)d/%%(page_count)d ...',
        \ a:lookup, client.apiname,
        \)
  let fetched_entries = client.retrieve({
        \ 'url': url,
        \ 'param': {
        \   'since': since,
        \ },
        \ 'indicator': indicator,
        \ 'python': options.python,
        \})
  redraw | call gista#util#prompt#echo(
        \ 'Updating entry/gist caches of gists ...'
        \)
  call s:remove_gists_cache(client, fetched_entries)
  let index = empty(since) || a:lookup ==# 'public'
        \ ? s:replace_entries_cache(client, fetched_entries, a:lookup)
        \ : s:update_entries_cache(client, fetched_entries, a:lookup)
  if a:lookup ==# username . '/starred'
    let starred_cache = {}
    for entry in index.entries
      let starred_cache[entry.id] = 1
    endfor
    call client.starred_cache.set(username, starred_cache)
  endif
  redraw
  return index
endfunction
function! gista#resource#gists#post(filenames, contents, ...) abort
  let options = extend({
        \ 'description': '',
        \ 'public': 0,
        \}, get(a:000, 0, {})
        \)
  let client   = gista#client#get()
  let username = client.get_authorized_username()

  " Create a gist instance
  let gist = {
        \ 'description': options.description,
        \ 'public': options.public ? s:J.true : s:J.false,
        \ 'files': {},
        \}
  let counter = 1
  for [filename, content] in s:L.zip(a:filenames, a:contents)
    if empty(filename)
      let filename = printf('gista-file%d', counter)
      let counter += 1
    endif
    let gist.files[filename] = content
  endfor

  redraw
  call gista#util#prompt#echo(printf(
        \ 'Posting contents to create a new gist in %s ...',
        \ client.apiname,
        \))
  let res = client.post('gists', gist)
  redraw
  if res.status == 201
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:J.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_last_modified = s:G.parse_response_last_modified(res)
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Updating caches of a gist %s in %s ...',
          \ gist.id, client.apiname,
          \))
    call s:add_gist_cache(client, gist)
    call s:add_entry_cache(client, gist, [
          \ username,
          \ gist.public ? 'public' : '',
          \])
    redraw
    return gist
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#gists#patch(gistid, ...) abort
  let options = extend({
        \ 'force': 0,
        \ 'description': 0,
        \ 'filenames': [],
        \ 'contents': [],
        \}, get(a:000, 0, {})
        \)
  let client   = gista#client#get()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Patching a gist cannot be performed as an anonymous user',
          \)
  endif

  " Check if a remote content of a gist is modified
  let gist = gista#resource#gists#get(a:gistid, {
        \ 'cache': options.force ? s:CACHE_FORCED : s:CACHE_DISABLED,
        \})
  if !options.force && gist._gista_modified
    call gista#util#prompt#throw(printf(
          \ 'A remote content of gist %s in %s is modified from last access.',
          \ a:gistid, client.apiname,
          \))
  endif

  " Create a partial gist instance
  let partial = {
        \ 'files': {},
        \ 'description': type(options.description) == type('')
        \   ? options.description
        \   : gist.description
        \}
  if type(options.description) == type('')
    let partial.description = options.description
  endif
  for [filename, content] in s:L.zip(options.filenames, options.contents)
    if empty(content)
      let partial.files[filename] = s:J.null
    else
      let partial.files[filename] = s:D.pick(content, [
            \ 'filename',
            \ 'content',
            \])
    endif
  endfor

  redraw
  call gista#util#prompt#echo(printf(
        \ 'Patching contents to a gist %s in %s ...',
        \ gist.id, client.apiname,
        \))
  let url = 'gists/' . a:gistid
  let res = client.patch(url, partial)
  redraw
  if res.status == 200
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:J.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_last_modified = s:G.parse_response_last_modified(res)
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Updating caches of a gist %s in %s ...',
          \ gist.id, client.apiname,
          \))
    call s:add_gist_cache(client, gist)
    call s:update_entry_cache(client, gist, [
          \ username,
          \ gist.public ? 'public' : '',
          \])
    redraw
    return gist
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#gists#delete(gistid, ...) abort
  let options = extend({
        \ 'force': 0,
        \}, get(a:000, 0, {})
        \)
  let client   = gista#client#get()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Deleting a gist cannot be performed as an anonymous user',
          \)
  endif

  " Check if a remote content of a gist is modified
  let gist = gista#resource#gists#get(a:gistid, {
        \ 'cache': options.force ? s:CACHE_FORCED : s:CACHE_DISABLED,
        \})
  if !options.force && get(gist, '_gista_modified', 1)
    call gista#util#prompt#throw(printf(
          \ 'A remote content of gist %s in %s is modified from last access.',
          \ a:gistid, client.apiname,
          \))
  endif

  redraw
  call gista#util#prompt#echo(printf(
        \ 'Deleting a gist %s in %s ...',
        \ gist.id, client.apiname,
        \))
  let url = 'gists/' . a:gistid
  let res = client.delete(url)
  redraw
  if res.status == 204
    call gista#util#prompt#echo(printf(
          \ 'Updating caches of a gist %s in %s ...',
          \ gist.id, client.apiname,
          \))
    call s:remove_gist_cache(client, gist)
    call s:remove_entry_cache(client, gist, [
          \ gista#resource#gists#get_gist_owner(gist),
          \ username,
          \ empty(username) ? '' : username . '/starred',
          \ 'public',
          \])
    redraw
    return
  endif
  call gista#client#throw(res)
endfunction

function! gista#resource#gists#_add_gist_cache(...) abort
  return call('s:add_gist_cache', a:000)
endfunction
function! gista#resource#gists#_add_entry_cache(...) abort
  return call('s:add_entry_cache', a:000)
endfunction
function! gista#resource#gists#_remove_entry_cache(...) abort
  return call('s:remove_entry_cache', a:000)
endfunction
function! gista#resource#gists#_retrieve_entry_cache(...) abort
  return call('s:retrieve_entry_cache', a:000)
endfunction

function! gista#resource#gists#is_modified(lhs, rhs) abort
  let lhs = s:D.omit(a:lhs, ['updated_at', '_gista_last_modified'])
  let rhs = s:D.omit(a:rhs, ['updated_at', '_gista_last_modified'])
  return string(lhs) !=# string(rhs)
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
