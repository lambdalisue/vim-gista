let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')
let s:J = s:V.import('Web.JSON')

" A content size limit for downloading via HTTP
" https://developer.github.com/v3/gists/#truncation
let s:CONTENT_SIZE_LIMIT = 10 * 1024 * 1024

function! s:get_available_gistids() abort " {{{
  let client = gista#api#get_current_client()
  let lookup = client.get_authorized_username()
  let lookup = empty(lookup) ? 'public' : lookup
  let entries = client.entry_cache.get(lookup, [])
  return map(copy(entries), 'v:val.id')
endfunction " }}}
function! s:get_valid_gistid(gistid) abort " {{{
  call gista#util#validate#not_empty(
        \ a:gistid,
        \ 'A gist ID cannot be empty',
        \)
  call gista#util#validate#pattern(
        \ a:gistid, '^\w\{,20}\%(/\w\+\)\?$',
        \ 'A gist ID "%value" requires to follow "%pattern"'
        \)
  return a:gistid
endfunction " }}}
function! s:get_gistid(gistid) abort " {{{
  if empty(a:gistid)
    redraw
    let gistid = gista#util#prompt#ask(
          \ 'Please input a gist id: ', '',
          \ 'customlist,gista#api#gists#complete_gistid',
          \)
  else
    let gistid = a:gistid
  endif
  return s:get_valid_gistid(gistid)
endfunction " }}}

function! s:get_available_filenames(gist) abort " {{{
  " Remove files more thant 10 MiB which cannot download with HTTP protocol
  return filter(
        \ keys(a:gist.files),
        \ 'a:gist.files[v:val].size < s:CONTENT_SIZE_LIMIT'
        \)
endfunction " }}}
function! s:get_valid_filename(gist, filename) abort " {{{
  call gista#util#validate#not_empty(
        \ a:filename,
        \ 'A filename cannot be empty',
        \)
  call gista#util#validate#exists(
        \ a:filename, s:get_available_filenames(a:gist),
        \ printf(
        \   'A filename "%s" is not found in "%s" or more than 10 MiB',
        \   a:gist.id, a:filename,
        \ ),
        \)
  return a:filename
endfunction " }}}
function! s:get_filename(gist, filename) abort " {{{
  if empty(a:filename)
    let available_filenames = s:get_available_filenames(a:gist)
    if len(available_filenames) == 0
      call gista#util#prompt#throw(
            \ printf(
            \   'No available files are found in a gist "%s".',
            \   a:gist.id
            \ ),
            \ 'Note that a file which is more than 10 MiB is not available.',
            \ printf(
            \   'You need to clone the gist via the URL "%s".',
            \   a:gist.git_pull_url
            \ ),
            \)
    elseif len(available_filenames) == 1
      let filename = available_filenames[0]
    else
      redraw
      let ret = gista#util#prompt#inputlist(
            \ 'Please select a filename: ',
            \ available_filenames,
            \)
      let filename = ret ? available_filenames[ret - 1] : ''
    endif
  else
    let filename = a:filename
  endif
  return s:get_valid_filename(a:gist, filename)
endfunction " }}}

function! s:get_valid_lookup(lookup) abort " {{{
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  if !empty(username)
        \ && (a:lookup ==# username || a:lookup ==# username . '/starred')
    return a:lookup
  endif
  call gista#util#validate#pattern(
        \ a:lookup, '^\w*$',
        \ 'A lookup "%value" requires to follow "%pattern"'
        \)
  return a:lookup
endfunction " }}}
function! s:get_lookup(lookup) abort " {{{
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  let lookup = empty(a:lookup)
        \ ? empty(g:gista#api#gists#list_default_lookup)
        \   ? empty(username)
        \     ? 'public'
        \     : username
        \   : g:gista#api#gists#list_default_lookup
        \ : a:lookup
  return s:get_valid_lookup(lookup)
endfunction " }}}

function! s:pick_necessary_params_of_content(content) abort " {{{
  return {
        \ 'size': a:content.size,
        \ 'type': a:content.type,
        \ 'language': a:content.language,
        \}
endfunction " }}}
function! s:pick_necessary_params_of_entry(gist) abort " {{{
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
        \ '_gista_partial': get(a:gist, '_gista_partial', 1),
        \ '_gista_modified': get(a:gist, '_gista_modified', 0),
        \}
endfunction " }}}

" Resource API
function! gista#api#gists#get_cache(gistid) abort " {{{
  let client = gista#api#get_current_client()
  let gistid = s:get_gistid(a:gistid)
  return client.content_cache.get(gistid, {})
endfunction " }}}
function! gista#api#gists#get(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'fresh': 0,
        \}, get(a:000, 0, {})
        \)
  let gist = gista#api#gists#get_cache(a:gistid)
  if !options.fresh && !empty(gist)
    return gist
  endif

  let client = gista#api#get_current_client()
  let gistid = s:get_gistid(a:gistid)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Requesting a gist %s in %s as %s ...',
          \ gistid,
          \ client.apiname,
          \ empty(client.get_authorized_username())
          \   ? 'an anonymous user'
          \   : client.get_authorized_username(),
          \))
  endif
  let res = client.get('gists/' . gistid)
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:J.decode(res.content)
  if res.status != 200
    call gista#api#throw_api_exception(res)
  endif
  let gist = gista#gist#mark_fetched(res.content)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Updating content cache of a gist "%s" in %s...',
          \ gist.id,
          \ client.apiname,
          \))
  endif
  call client.content_cache.set(gist.id, gist)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Updating entry caches of a gist "%s" in %s...',
          \ gist.id,
          \ client.apiname,
          \))
  endif
  call gista#gist#apply_to_entry_cache(
        \ client, gist.id,
        \ function('gista#gist#mark_fetched'),
        \)
  call gista#gist#apply_to_entry_cache(
        \ client, gist.id,
        \ function('gista#gist#unmark_modified'),
        \)
  return gist
endfunction " }}}
function! gista#api#gists#list_cache(lookup) abort " {{{
  let client = gista#api#get_current_client()
  let lookup = s:get_lookup(a:lookup)
  let entries = client.entry_cache.get(lookup, [])
  return {
        \ 'lookup': lookup,
        \ 'entries': entries,
        \ 'since': len(entries)
        \   ? entries[0].updated_at
        \   : '',
        \}
endfunction " }}}
function! gista#api#gists#list(lookup, ...) abort " {{{
  let options = extend({
        \ 'since': 1,
        \ 'fresh': 0,
        \ 'python': has('python') || has('python3'),
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  if options.verbose
    redraw
    call gista#util#prompt#echo('Loading gists from cache ...')
  endif
  let cached_content = gista#api#gists#list_cache(a:lookup)
  if !options.fresh && !empty(cached_content.entries)
    return cached_content
  endif
  " assign page/since/last_page
  let client = gista#api#get_current_client()
  let lookup = s:get_lookup(a:lookup)
  let since = type(options.since) == type(0)
        \ ? options.since
        \   ? len(cached_content.entries)
        \     ? cached_content.entries[0].updated_at
        \     : ''
        \   : ''
        \ : options.since
  " find a corresponding url
  let username = client.get_authorized_username()
  if lookup ==# 'public'
    let url = 'gists/public'
  elseif !empty(username) && lookup ==# username
    let url = 'gists'
  elseif !empty(username) && lookup ==# username . '/starred'
    let url = 'gists/starred'
  elseif !empty(lookup)
    let url = printf('users/%s/gists', lookup)
  else
    let url = 'gists/public'
  endif
  " fetch entries
  let indicator = printf(
        \ 'Requesting gists of %s in %s as %s %%%%(page)d/%%(page_count)d ...',
        \ lookup,
        \ client.apiname,
        \ empty(username)
        \   ? 'an anonymous user'
        \   : username,
        \)
  let cached_entries  = cached_content.entries
  let fetched_entries = client.retrieve({
        \ 'verbose': options.verbose,
        \ 'url': url,
        \ 'param': {
        \   'since': since,
        \ },
        \ 'indicator': indicator,
        \ 'python': options.python,
        \})
  " Remove unnecessary params
  if options.verbose
    redraw
    call gista#util#prompt#echo('Removing unnecessary params of gists ...')
  endif
  call map(
        \ fetched_entries,
        \ 's:pick_necessary_params_of_entry(v:val)'
        \)
  " Create fetched entry gistids
  let fetched_entry_ids = map(copy(fetched_entries), 'v:val.id')

  if empty(since) || lookup ==# 'public'
    " if 'since' is empty, fetched_entries should represent entire entires in
    " API thus no entry merging is required.
    " if 'lookup' is 'public', the entries change too often and cache size
    " would be infinity thus forget about the previous cached entries
    let entries = fetched_entries
  else
    if options.verbose
      redraw
      call gista#util#prompt#echo('Removing duplicated entries ...')
    endif
    " Note: fetched_entries is also modified
    let entries = extend(fetched_entries, filter(
          \ cached_content.entries,
          \ 'index(fetched_entry_ids, v:val.id) == -1'
          \))
  endif

  " Remove corresponding content cache
  if options.verbose
    redraw
    call gista#util#prompt#echo('Removing corresponding content caches ...')
  endif
  call map(copy(fetched_entry_ids), 'client.content_cache.remove(v:val)')

  " Update entry cache
  if options.verbose
    redraw
    call gista#util#prompt#echo('Updating entry caches ...')
  endif
  call client.entry_cache.set(lookup, entries)

  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ '%d gist entries were listed.',
          \ len(fetched_entry_ids),
          \))
  endif
  return {
        \ 'lookup': lookup,
        \ 'entries': entries,
        \ 'since': since,
        \}
endfunction " }}}
function! gista#api#gists#post(filenames, contents, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'description': g:gista#api#gists#post_interactive_description,
        \ 'public': g:gista#api#gists#post_default_public,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()

  " Description
  let description = ''
  if type(options.description) == type(0)
    if options.description
      let description = gista#util#prompt#ask(
            \ 'Please input a description of a gist: ',
            \)
    endif
  else
    let description = options.description
  endif
  if empty(description) && !g:gista#api#gists#post_allow_empty_description
    call gista#util#prompt#throw(
          \ 'An empty description is not allowed',
          \ 'See ":help g:gista#gists#post_allow_empty_description" for detail',
          \)
  endif

  " Create a gist instance
  let gist = {
        \ 'description': description,
        \ 'public': options.public ? s:J.true : s:J.false,
        \ 'files': {},
        \}
  for [filename, content] in s:L.zip(a:filenames, a:contents)
    if type(content) == type('')
      let gist.files[filename] = { 'content': content }
    elseif type(content) == type([])
      let gist.files[filename] = { 'content': join(content, "\n") }
    else
      let gist.files[filename] = content
    endif
    unlet content
  endfor

  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Posting a gist to %s %s ...',
          \ client.apiname,
          \ empty(username)
          \   ? 'as an anonymous user'
          \   : username,
          \))
  endif

  let url = 'gists'
  let res = client.post(url, gist)
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:J.decode(res.content)
  if res.status != 201
    call gista#api#throw_api_exception(res)
  endif

  let gist = gista#gist#mark_fetched(res.content)
  call client.content_cache.set(gist.id, gist)
  if !empty(username)
    call gista#gist#apply_to_entry_cache(
          \ client, gist.id,
          \ function('gista#gist#mark_fetched'),
          \)
    call gista#gist#apply_to_entry_cache(
          \ client, gist.id,
          \ function('gista#gist#unmark_modified'),
          \)
  endif
  return gist
endfunction " }}}
function! gista#api#gists#patch(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'fresh': 0,
        \ 'description': g:gista#api#gists#patch_interactive_description,
        \ 'filenames': [],
        \ 'contents': [],
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Patching a gist cannot be performed as an anonymous user',
          \)
  endif

  let gist = gista#api#gists#get(a:gistid, {
        \ 'verbose': options.verbose,
        \ 'fresh': options.fresh,
        \})

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

  " Create a gist instance
  let partial_gist = {
        \ 'description': description,
        \ 'files': {},
        \}
  for [filename, content] in s:L.zip(options.filenames, options.contents)
    if type(content) == type('')
      let partial_gist.files[filename] = { 'content': content }
    elseif type(content) == type([])
      let partial_gist.files[filename] = { 'content': join(content, "\n") }
    elseif type(content) == type(0) && !content
      let partial_gist.files[filename] = s:J.null
    else
      let partial_gist.files[filename] = content
    endif
    unlet content
  endfor

  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Patching a gist "%s" to %s as %s...',
          \ gist.id,
          \ client.apiname,
          \ username,
          \))
  endif
  let res = client.patch('gists/' . gist.id, partial_gist)
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:J.decode(res.content)
  if res.status != 200
    call gista#api#throw_api_exception(res)
  endif

  let gist = gista#gist#mark_fetched(res.content)
  call client.content_cache.set(gist.id, gist)
  call gista#gist#apply_to_entry_cache(
        \ client, gist.id,
        \ function('gista#gist#mark_fetched'),
        \)
  call gista#gist#apply_to_entry_cache(
        \ client, gist.id,
        \ function('gista#gist#unmark_modified'),
        \)
  return gist
endfunction " }}}
function! gista#api#gists#delete(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Deleting a gist cannot be performed as an anonymous user',
          \)
  endif

  let gistid = s:get_gistid(a:gistid)

  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Deleting a gist "%s" in %s as %s...',
          \ gistid,
          \ client.apiname,
          \ username,
          \))
  endif
  let res = client.delete('gists/' . gistid)
  if res.status != 204
    call gista#api#throw_api_exception(res)
  endif
endfunction " }}}

" Utility function
function! gista#api#gists#get_content(gist, filename, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'fresh': 0,
        \}, get(a:000, 0, {})
        \)
  let filename = s:get_filename(a:gist, a:filename)
  let file = get(a:gist.files, filename, {})
  if empty(file)
    call gista#util#prompt#throw(
          \ '404: Not found',
          \ printf(
          \   'A filename "%s" is not found in a gist "%s"',
          \   filename, a:gist.id,
          \ ),
          \)
  elseif file.truncated
    " request the file content if the content is truncated
    let client = gista#api#get_current_client()
    let res = client.get(file.raw_url, {}, {}, {
          \ 'verbose': options.verbose,
          \})
    if res.status != 200
      call gista#api#throw_api_exception(res)
    endif
    let file.truncated = 0
    let file.content = res.content
  endif
  return {
        \ 'filename': filename,
        \ 'content': split(file.content, '\r\?\n'),
        \}
endfunction " }}}
function! gista#api#gists#complete_gistid(arglead, cmdline, cursorpos, ...) abort " {{{
  return filter(
        \ s:get_available_gistids(),
        \ 'v:val =~# "^" . a:arglead',
        \)
endfunction " }}}
function! gista#api#gists#complete_filename(arglead, cmdline, cursorpos, ...) abort " {{{
  let options = extend({
        \ 'gistid': '',
        \}, get(a:000, 0, {}),
        \)
  let clinet = gista#api#get_current_client()
  let gist = gista#api#gists#get_cache(options.gistid)
  if empty(gist)
    return []
  endif
  let available_filenames = s:get_available_filenames(gist)
  return filter(available_filenames, 'v:val =~# "^" . a:arglead')
endfunction " }}}

" Configure variables
call gista#define_variables('api#gists', {
      \ 'list_default_lookup': '',
      \ 'post_interactive_description': 1,
      \ 'post_allow_empty_description': 0,
      \ 'post_default_public': 1,
      \ 'patch_interactive_description': 1,
      \ 'patch_allow_empty_description': 0,
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
