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

function! s:remove_unmodified(content_cache, gistid) abort " {{{
  if !a:content_cache.has(a:gistid)
    return
  endif
  if !gista#gist#is_modified(a:content_cache.get(a:gistid))
    call a:content_cache.remove(a:gistid)
  endif
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
  if !empty(gist)
    if options.fresh &&gista#gist#is_modified(gist)
      if !gista#util#prompt#asktf(join([
          \ 'The changes of the gist content has not been posted yet.',
          \ 'Are you sure you want to overwrite the changes? ',
          \], "\n"))
        return gist
      endif
    elseif !options.fresh
      return gist
    endif
  endif

  let client = gista#api#get_current_client()
  let gistid = s:get_gistid(a:gistid)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Requesting a gist "%s" in %s %s ...',
          \ gistid,
          \ client.apiname,
          \ empty(client.get_authorized_username())
          \   ? 'as an anonymous user'
          \   : 'as ' . client.get_authorized_username(),
          \))
  endif
  let res = client.get('gists/' . gistid, {}, {}, {
        \ 'verbose': options.verbose,
        \})
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
        \}, get(a:000, 0, {})
        \)
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
        \ 'Requesting gists of "%s" in %s as %s %%%%d/%%d ...',
        \ lookup,
        \ client.apiname,
        \ empty(username)
        \   ? 'an anonymous user'
        \   : username,
        \)
  if options.python
    let fetched_entries = gista#util#fetcher#python(url, indicator, {
          \ 'since': since,
          \})
  else
    let fetched_entries = gista#util#fetcher#vim(url, indicator, {
          \ 'since': since,
          \})
  endif
  redraw
  call gista#util#prompt#echo('Removing unnecessary params ...')
  call map(
        \ fetched_entries,
        \ 'gista#gist#pick_necessary_params_of_entry(v:val)'
        \)

  if empty(since)
    " fetched_entries are corresponding to the actual entries in API
    " so overwrite cache_entries with fetched_entries
    let entries = fetched_entries
  else
    " fetched_entries are partial entries in API
    " so merge entries with cached_entries
    redraw
    call gista#util#prompt#echo('Removing duplicated gist entries ...')
    let entries = gista#gist#merge_entries(
          \ fetched_entries, cached_content.entries
          \)
  endif

  redraw
  call gista#util#prompt#echo('Updating entry caches ...')
  call client.entry_cache.set(lookup, entries)

  redraw
  call gista#util#prompt#echo('Removing corresponding content caches ...')
  call map(
        \ copy(fetched_entries),
        \ 's:remove_unmodified(client.content_cache, v:val.id)'
        \)

  redraw
  call gista#util#prompt#echo(printf(
        \ '%d gist entries were listed.',
        \ len(fetched_entries),
        \))
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
  let res = client.post(url, gist, {}, {
        \ 'verbose': options.verbose,
        \})
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
  let res = client.patch('gists/' . gist.id, partial_gist, {}, {
        \ 'verbose': options.verbose,
        \})
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
