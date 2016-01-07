let s:save_cpo = &cpo
set cpo&vim

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

function! s:validate_lookup(client, lookup) abort
  let username = a:client.get_authorized_username()
  if !empty(username)
        \ && (a:lookup ==# username || a:lookup ==# username . '/starred')
    return
  endif
  call gista#util#validate#pattern(
        \ a:lookup, '^\w*$',
        \ 'A lookup "%value" requires to follow "%pattern"'
        \)
endfunction
function! s:get_valid_lookup(client, lookup) abort
  let username = a:client.get_authorized_username()
  let lookup = empty(a:lookup)
        \ ? empty(g:gista#command#list#default_lookup)
        \   ? empty(username) ? 'public' : username
        \   : g:gista#command#list#default_lookup
        \ : a:lookup
  let lookup = !empty(username)
        \ && lookup ==# 'starred' ? username . '/starred' : lookup
  call s:validate_lookup(a:client, lookup)
  return lookup
endfunction

function! s:get(client, lookup, options) abort
  call gista#indicate(a:options, printf(
        \ 'Loading gist index of %s in %s from a local cache ...',
        \ a:lookup, a:client.apiname,
        \))
  let index = extend(
        \ gista#resource#index#get_pseudo_index(),
        \ a:client.index_cache.get(a:lookup, {})
        \)
  return index
endfunction
function! s:set(client, index, lookup, options) abort
  call gista#indicate(a:options, printf(
        \ 'Saving gist index of %s in %s to a local cache ...',
        \ a:lookup, a:client.apiname,
        \))
  let index = extend(
        \ gista#resource#index#get_pseudo_index(),
        \ a:index
        \)
  call a:client.index_cache.set(a:lookup, a:index)
endfunction

function! s:assign_entries(client, lookup, entries, options) abort
  let index = s:get(a:client, a:lookup, a:options)
  let index.entries = a:entries
  call a:client.index_cache.set(a:lookup, index)
  return index
endfunction
function! s:append_entries(client, lookup, entries, options) abort
  let ids = map(copy(a:entries), 'v:val.id')
  let index = s:get(a:client, a:lookup, a:options)
  call filter(index.entries, 'index(ids, v:val.id) == -1')
  call extend(index.entries, a:entries, 0)
  call a:client.index_cache.set(a:lookup, index)
endfunction

function! s:retrieve_entry(client, lookup, gistid, options) abort
  if a:client.index_cache.has(a:lookup)
    let index = s:get(a:client, a:lookup, a:options)
    let entry_ids = map(copy(index.entries), 'v:val.id')
    let found_idx = index(entry_ids, a:gistid)
    if found_idx >= 0
      return index.entries[found_idx]
    endif
  endif
  return {}
endfunction
function! s:append_entry(client, lookup, entry, options) abort
  let index = s:get(a:client, a:lookup, a:options)
  call filter(index.entries, 'v:val.id !=# a:entry.id')
  call insert(index.entries, a:entry, 0)
  call a:client.index_cache.set(a:lookup, index)
endfunction
function! s:update_entry(client, lookup, entry, options) abort
  if a:client.index_cache.has(a:lookup)
    let index = s:get(a:client, a:lookup, a:options)
    call map(
          \ index.entries,
          \ 'v:val.id ==# a:entry.id ? a:entry : v:val'
          \)
    call a:client.index_cache.set(a:lookup, index)
  endif
endfunction
function! s:remove_entry(client, lookup, gistid, options) abort
  if a:client.index_cache.has(a:lookup)
    let index = s:get(a:client, a:lookup, a:options)
    call filter(index.entries, 'v:val.id !=# a:gistid')
    call a:client.index_cache.set(a:lookup, index)
  endif
endfunction


function! gista#resource#index#complete_lookup(arglead, cmdline, cursorpos, ...) abort
  try
    let client = gista#client#get()
    let lookups = [
          \ client.get_authorized_username(),
          \ 'starred', 'public',
          \]
    call extend(lookups, client.token_cache.keys())
    call filter(lookups, '!empty(v:val)')
    return filter(uniq(lookups), 'v:val =~# "^" . a:arglead')
  catch /^vim-gista: ValidationError:/
    return []
  endtry
endfunction
function! gista#resource#index#validate_lookup(lookup) abort
  let client   = gista#client#get()
  call s:validate_lookup(client, a:lookup)
endfunction
function! gista#resource#index#get_valid_lookup(lookup) abort
  let client  = gista#client#get()
  return s:get_valid_lookup(client, a:lookup)
endfunction

function! gista#resource#index#get_pseudo_index() abort
  return {
        \ 'entries': [],
        \ '_gista_fetched': 0,
        \}
endfunction
function! gista#resource#index#get_pseudo_index_entry(gistid) abort
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
function! gista#resource#index#get_pseudo_index_entry_file() abort
  return {
        \ 'size': 0,
        \ 'type': '',
        \ 'language': '',
        \}
endfunction

function! gista#resource#index#get(lookup, ...) abort
  call gista#resource#index#validate_lookup(a:lookup)
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  return s:get(client, a:lookup, options)
endfunction
function! gista#resource#index#set(index, lookup, ...) abort
  call gista#resource#index#validate_lookup(a:lookup)
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  return s:set(client, a:lookup, a:index, options)
endfunction

function! gista#resource#index#assign_entries(lookup, gists, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client  = gista#client#get()
  let lookup  = s:get_valid_lookup(client, a:lookup)
  let entries = map(
        \ copy(a:gists),
        \ 's:pick_necessary_params_of_index_entry(v:val)'
        \)
  call s:assign_entries(client, lookup, entries, options)
endfunction
function! gista#resource#index#append_entries(lookup, gists, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client  = gista#client#get()
  let lookup  = s:get_valid_lookup(client, a:lookup)
  let entries = map(
        \ copy(a:gists),
        \ 's:pick_necessary_params_of_index_entry(v:val)'
        \)
  call s:append_entries(client, lookup, entries, options)
endfunction

function! gista#resource#index#retrieve_entry(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'lookups': [],
        \}, get(a:000, 0, {})
        \)
  let client  = gista#client#get()
  if empty(options.lookups)
    let username = client.get_authorized_username()
    let lookups = [
          \ username,
          \ empty(username) ? '' : username . '/starred',
          \ 'public',
          \]
    call extend(lookups, client.token_cache.keys())
    call filter(lookups, '!empty(v:val)')
  else
    let lookups = map(
          \ copy(options.lookup),
          \ 's:get_valid_lookup(client, v:val)'
          \)
  endif

  for lookup in uniq(lookups)
    let entry = s:retrieve_entry(client, lookup, a:gistid, options)
    if !empty(entry)
      return entry
    endif
  endfor
  return gista#resource#index#get_pseudo_index_entry(a:gistid)
endfunction
function! gista#resource#index#append_entry(gist, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'lookups': [],
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  let entry  = s:pick_necessary_params_of_index_entry(a:gist)
  if empty(options.lookups)
    let username = client.get_authorized_username()
    let lookups = [ username, 'public' ]
    call filter(lookups, '!empty(v:val)')
  else
    let lookups = map(
          \ copy(options.lookup),
          \ 's:get_valid_lookup(client, v:val)'
          \)
  endif

  for lookup in uniq(lookups)
    call s:append_entry(client, lookup, entry, options)
  endfor
endfunction
function! gista#resource#index#update_entry(gist, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'lookups': [],
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  let entry  = s:pick_necessary_params_of_index_entry(a:gist)
  if empty(options.lookups)
    let username = client.get_authorized_username()
    let lookups = [
          \ username,
          \ empty(username) ? '' : username . '/starred',
          \ 'public',
          \]
    call extend(lookups, client.token_cache.keys())
    call filter(lookups, '!empty(v:val)')
  else
    let lookups = map(
          \ copy(options.lookup),
          \ 's:get_valid_lookup(client, v:val)'
          \)
  endif

  for lookup in uniq(lookups)
    call s:update_entry(client, lookup, entry, options)
  endfor
endfunction
function! gista#resource#index#remove_entry(gist, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'lookups': [],
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  let entry  = s:pick_necessary_params_of_index_entry(a:gist)
  if empty(options.lookups)
    let username = client.get_authorized_username()
    let lookups = [
          \ username,
          \ empty(username) ? '' : username . '/starred',
          \ 'public',
          \]
    call filter(lookups, '!empty(v:val)')
  else
    let lookups = map(
          \ copy(options.lookup),
          \ 's:get_valid_lookup(client, v:val)'
          \)
  endif

  for lookup in uniq(lookups)
    call s:remove_entry(client, lookup, entry, options)
  endfor
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
