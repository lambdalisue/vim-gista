let s:V = gista#vital()
let s:List = s:V.import('Data.List')

" A content size limit for downloading via HTTP
" https://developer.github.com/v3/gists/#truncation
let s:CONTENT_SIZE_LIMIT = 10 * 1024 * 1024

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
        \ 'html_url': a:gist.html_url,
        \ 'files': map(
        \   copy(a:gist.files),
        \   's:pick_necessary_params_of_index_entry_file(v:val)'
        \ ),
        \ 'created_at': a:gist.created_at,
        \ 'updated_at': a:gist.updated_at,
        \ '_gista_fetched': get(a:gist, '_gista_fetched', 0),
        \}
endfunction

function! s:validate_gistid(gistid) abort
  call gista#util#validate#not_empty(
        \ a:gistid,
        \ 'A gist ID cannot be empty',
        \)
  call gista#util#validate#pattern(
        \ a:gistid, '^\w\{,32}\%(/\w\+\)\?$',
        \ 'A gist ID "%value" requires to follow "%pattern"'
        \)
endfunction
function! s:validate_filename(filename) abort
  call gista#util#validate#not_empty(
        \ a:filename,
        \ 'A filename cannot be empty',
        \)
endfunction
function! s:validate_lookup(client, lookup) abort
  let username = a:client.get_authorized_username()
  if !empty(username)
        \ && (a:lookup ==# username || a:lookup ==# username . '/starred')
    return
  endif
  call gista#util#validate#pattern(
        \ a:lookup, '^[-0-9a-zA-Z_]*$',
        \ 'A lookup "%value" requires to follow "%pattern"'
        \)
endfunction

function! s:get_index(client, lookup, options) abort
  call gista#util#prompt#indicate(a:options, printf(
        \ 'Loading a gist index of %s in %s from a local cache ...',
        \ a:lookup, a:client.apiname,
        \))
  let index = extend(
        \ gista#resource#local#get_pseudo_index(),
        \ a:client.index_cache.get(a:lookup, {})
        \)
  return index
endfunction
function! s:get_gist(client, gistid, options) abort
  call gista#util#prompt#indicate(a:options, printf(
        \ 'Loading a gist %s in %s from a local cache ...',
        \ a:gistid, a:client.apiname,
        \))
  if a:client.gist_cache.has(a:gistid)
    let gist = extend(
          \ gista#resource#local#get_pseudo_gist(a:gistid),
          \ a:client.gist_cache.get(a:gistid, {}),
          \)
  else
    let gist = extend(
          \ gista#resource#local#get_pseudo_gist(a:gistid),
          \ gista#resource#local#retrieve_index_entry(a:gistid, a:options),
          \)
  endif
  return gist
endfunction
function! s:get_gist_file(client, gist, filename, options) abort
  call gista#util#prompt#indicate(a:options, printf(
        \ 'Loading a file %s of gist %s in %s from a local cache ...',
        \ a:filename, a:gist.id, a:client.apiname,
        \))
  let file = extend(
        \ gista#resource#local#get_pseudo_gist_file(),
        \ get(a:gist.files, a:filename, {})
        \)
  return file
endfunction

function! s:assign_index_entries(client, lookup, entries, options) abort
  let index = s:get_index(a:client, a:lookup, a:options)
  let index._gista_fetched = 1
  let index.entries = a:entries
  call a:client.index_cache.set(a:lookup, index)
  return index
endfunction
function! s:append_index_entries(client, lookup, entries, options) abort
  let ids = map(copy(a:entries), 'v:val.id')
  let index = s:get_index(a:client, a:lookup, a:options)
  let index._gista_fetched = 1
  call filter(index.entries, 'index(ids, v:val.id) == -1')
  call extend(index.entries, a:entries, 0)
  call a:client.index_cache.set(a:lookup, index)
  return index
endfunction

function! s:retrieve_index_entry(client, lookup, gistid, options) abort
  if a:client.index_cache.has(a:lookup)
    let index = s:get_index(a:client, a:lookup, a:options)
    let entry_ids = map(copy(index.entries), 'v:val.id')
    let found_idx = index(entry_ids, a:gistid)
    if found_idx >= 0
      return index.entries[found_idx]
    endif
  endif
  return {}
endfunction
function! s:append_index_entry(client, lookup, entry, options) abort
  let index = s:get_index(a:client, a:lookup, a:options)
  call filter(index.entries, 'v:val.id !=# a:entry.id')
  call insert(index.entries, a:entry, 0)
  call a:client.index_cache.set(a:lookup, index)
endfunction
function! s:update_index_entry(client, lookup, entry, options) abort
  if a:client.index_cache.has(a:lookup)
    let index = s:get_index(a:client, a:lookup, a:options)
    call map(
          \ index.entries,
          \ 'v:val.id ==# a:entry.id ? a:entry : v:val'
          \)
    call a:client.index_cache.set(a:lookup, index)
  endif
endfunction
function! s:remove_index_entry(client, lookup, gistid, options) abort
  if a:client.index_cache.has(a:lookup)
    let index = s:get_index(a:client, a:lookup, a:options)
    call filter(index.entries, 'v:val.id !=# a:gistid')
    call a:client.index_cache.set(a:lookup, index)
  endif
endfunction

function! s:append_gist(client, gist, options) abort
  call a:client.gist_cache.set(a:gist.id, a:gist)
endfunction
function! s:remove_gist(client, gistid, options) abort
  call a:client.gist_cache.remove(a:gistid)
endfunction
function! s:remove_gists(client, gistids, options) abort
  for gistid in a:gistids
    call a:client.gist_cache.remove(gistid)
  endfor
endfunction

function! gista#resource#local#validate_gistid(gistid) abort
  call s:validate_gistid(a:gistid)
endfunction
function! gista#resource#local#validate_filename(filename) abort
  call s:validate_filename(a:filename)
endfunction
function! gista#resource#local#validate_lookup(lookup) abort
  let client = gista#client#get()
  call s:validate_lookup(client, a:lookup)
endfunction

function! gista#resource#local#get_pseudo_index() abort
  return {
        \ 'entries': [],
        \ '_gista_fetched': 0,
        \}
endfunction
function! gista#resource#local#get_pseudo_index_entry(gistid) abort
  return {
        \ 'id': a:gistid,
        \ 'description': '',
        \ 'public': 0,
        \ 'html_url': '',
        \ 'files': {},
        \ 'created_at': '',
        \ 'updated_at': '',
        \ '_gista_fetched': 0,
        \}
endfunction
function! gista#resource#local#get_pseudo_index_entry_file() abort
  return {
        \ 'size': 0,
        \ 'type': '',
        \ 'language': '',
        \}
endfunction
function! gista#resource#local#get_pseudo_gist(gistid) abort
  return extend(gista#resource#local#get_pseudo_index_entry(a:gistid), {
        \ '_gista_last_modified': '',
        \})
endfunction
function! gista#resource#local#get_pseudo_gist_file() abort
  return extend(gista#resource#local#get_pseudo_index_entry_file(), {
        \ 'truncated': 1,
        \ 'content': '',
        \ 'raw_url': '',
        \})
endfunction

function! gista#resource#local#assign_index_entries(lookup, gists, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client  = gista#client#get()
  call s:validate_lookup(client, a:lookup)
  let entries = map(
        \ copy(a:gists),
        \ 's:pick_necessary_params_of_index_entry(v:val)'
        \)
  return s:assign_index_entries(client, a:lookup, entries, options)
endfunction
function! gista#resource#local#append_index_entries(lookup, gists, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client  = gista#client#get()
  call s:validate_lookup(client, a:lookup)
  let entries = map(
        \ copy(a:gists),
        \ 's:pick_necessary_params_of_index_entry(v:val)'
        \)
  return s:append_index_entries(client, a:lookup, entries, options)
endfunction

function! gista#resource#local#retrieve_index_entry(gistid, ...) abort
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
    let lookups = copy(options.lookups)
    call map(copy(lookups), 's:validate_lookup(client, v:val)')
  endif

  for lookup in s:List.uniq(lookups)
    let entry = s:retrieve_index_entry(client, lookup, a:gistid, options)
    if !empty(entry)
      return entry
    endif
  endfor
  return gista#resource#local#get_pseudo_index_entry(a:gistid)
endfunction
function! gista#resource#local#append_index_entry(gist, ...) abort
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
    let lookups = copy(options.lookups)
    call map(copy(lookups), 's:validate_lookup(client, v:val)')
  endif

  for lookup in s:List.uniq(lookups)
    call s:append_index_entry(client, lookup, entry, options)
  endfor
endfunction
function! gista#resource#local#update_index_entry(gist, ...) abort
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
    let lookups = copy(options.lookups)
    call map(copy(lookups), 's:validate_lookup(client, v:val)')
  endif

  for lookup in s:List.uniq(lookups)
    call s:update_index_entry(client, lookup, entry, options)
  endfor
endfunction
function! gista#resource#local#remove_index_entry(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'lookups': [],
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  if empty(options.lookups)
    let username = client.get_authorized_username()
    let lookups = [
          \ username,
          \ empty(username) ? '' : username . '/starred',
          \ 'public',
          \]
    call filter(lookups, '!empty(v:val)')
  else
    let lookups = copy(options.lookups)
    call map(copy(lookups), 's:validate_lookup(client, v:val)')
  endif

  for lookup in s:List.uniq(lookups)
    call s:remove_index_entry(client, lookup, a:gistid, options)
  endfor
endfunction

function! gista#resource#local#append_gist(gist, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  call s:append_gist(client, a:gist, options)
endfunction
function! gista#resource#local#remove_gist(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  call s:remove_gist(client, a:gistid, options)
endfunction
function! gista#resource#local#remove_gists(gistids, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  call s:remove_gists(client, a:gistids, options)
endfunction

function! gista#resource#local#list(lookup, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  call s:validate_lookup(client, a:lookup)
  return s:get_index(client, a:lookup, options)
endfunction
function! gista#resource#local#get(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  call s:validate_gistid(a:gistid)
  return s:get_gist(client, a:gistid, options)
endfunction
function! gista#resource#local#file(gist, filename, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#client#get()
  call s:validate_filename(a:filename)
  return s:get_gist_file(client, a:gist, a:filename, options)
endfunction

function! gista#resource#local#get_available_gistids() abort
  let client = gista#client#get()
  let lookup = client.get_authorized_username()
  let lookup = empty(lookup) ? 'public' : lookup
  let index = gista#resource#local#list(lookup)
  return map(copy(index.entries), 'v:val.id')
endfunction
function! gista#resource#local#get_available_filenames(gist) abort
  " Remove files more thant 10 MiB which cannot download with HTTP protocol
  return filter(
        \ keys(get(a:gist, 'files', {})),
        \ 'a:gist.files[v:val].size < s:CONTENT_SIZE_LIMIT'
        \)
endfunction

function! gista#resource#local#get_valid_gistid(gistid) abort
  if empty(a:gistid)
    redraw
    let gistid = gista#util#prompt#ask(
          \ 'Please input a gist id: ', '',
          \ 'customlist,gista#option#complete_gistid',
          \)
    if empty(gistid)
      call gista#throw('Cancel')
    endif
  else
    let gistid = a:gistid
  endif
  call s:validate_gistid(gistid)
  return gistid
endfunction
function! gista#resource#local#get_valid_filename(gist, filename) abort
  if empty(a:filename)
    let filenames = gista#resource#local#get_available_filenames(a:gist)
    if len(filenames) == 1
      let filename = filenames[0]
    elseif len(filenames) > 0
      redraw
      let filename = gista#util#prompt#select(
            \ 'Please select a filename: ',
            \ filenames,
            \)
      if empty(filename)
        call gista#throw('Cancel')
      endif
    else
      redraw
      let filename = gista#util#prompt#ask(
            \ 'Please input a filename: ', '',
            \ 'customlist,gista#option#complete_filename',
            \)
      if empty(filename)
        call gista#throw('Cancel')
      endif
    endif
  else
    let filename = a:filename
  endif
  call s:validate_filename(filename)
  return filename
endfunction
function! gista#resource#local#get_valid_lookup(lookup) abort
  let client = gista#client#get()
  let username = client.get_authorized_username()
  let lookup = empty(a:lookup)
        \ ? empty(username)
        \   ? 'public'
        \   : username
        \ : a:lookup
  let lookup = !empty(username) && lookup ==# 'starred'
        \ ? username . '/starred'
        \ : lookup
  call s:validate_lookup(client, lookup)
  return lookup
endfunction
