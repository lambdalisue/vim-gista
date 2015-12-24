let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')
let s:D = s:V.import('Data.Dict')
let s:J = s:V.import('Web.JSON')
let s:G = s:V.import('Web.API.GitHub')

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
        \ '_gista_fetched': get(a:gist, '_gista_fetched', 0),
        \ '_gista_modified': get(a:gist, '_gista_modified', 0),
        \}
endfunction " }}}

" Resource API
function! gista#api#gists#get(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'cache': 1,
        \}, get(a:000, 0, {})
        \)
  let gist = gista#api#gists#cache#get(a:gistid, options)
  " TODO
  " Check if the gist has modified and warn
  if options.cache && gist._gista_fetched
    return gist
  endif

  let gistid = gist.id
  let client = gista#api#get_current_client()
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
  let headers = {
        \ 'If-Modified-Since': gist._gista_last_modified,
        \}
  let res = client.get('gists/' . gistid, {}, headers)
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:J.decode(res.content)
  if res.status == 304
    " the content is not modified since the last request
    return gist
  elseif res.status == 200
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_modified = 0
    let gist._gista_last_modified = s:G.parse_response_last_modified(res)
    if options.verbose
      redraw
      call gista#util#prompt#echo(printf(
            \ 'Updating content cache of a gist "%s" in %s...',
            \ gist.id,
            \ client.apiname,
            \))
    endif
    call client.content_cache.set(gist.id, gist)
    " TODO
    " Update cached entries of the gist
    return gist
  endif
  " throw an exception
  call gista#api#throw_api_exception(res)
endfunction " }}}
function! gista#api#gists#list(lookup, ...) abort " {{{
  let options = extend({
        \ 'since': 1,
        \ 'cache': 1,
        \ 'python': has('python') || has('python3'),
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let content = gista#api#gists#cache#list(a:lookup, options)
  if options.cache && content._gista_fetched
    return content
  endif
  " assign page/since/last_page
  let client = gista#api#get_current_client()
  let lookup = content.lookup
  let since = type(options.since) == type(0)
        \ ? options.since ? content.since : ''
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
  " TODO
  " Handle 304 Not Modified
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
  call map(fetched_entries, 's:pick_necessary_params_of_entry(v:val)')

  " Create entries
  if empty(since) || lookup ==# 'public'
    let entries = fetched_entries
  else
    if options.verbose
      redraw
      call gista#util#prompt#echo('Removing duplicated entries ...')
    endif
    " Note: fetched_entries is also modified
    let fetched_entry_ids = map(copy(fetched_entries), 'v:val.id')
    let entries = extend(copy(fetched_entries), filter(
          \ content.entries,
          \ 'index(fetched_entry_ids, v:val.id) == -1'
          \))
  endif
  if options.verbose
    redraw
    call gista#util#prompt#echo('Updating entry caches ...')
  endif
  " TODO
  " Assign 'Last-Modified' correctly to handle 304 Not Modified
  let content = {
        \ 'lookup': lookup,
        \ 'entries': entries,
        \ 'since': since,
        \ '_gista_fetched': 1,
        \ '_gista_modified': 0,
        \ '_gista_last_modified': '',
        \}
  call client.entry_cache.set(lookup, content)
  " TODO
  " Remove corresponding content cache if the cache has not modified
  return content
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
    let gist.files[filename] = content
  endfor

  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Posting a gist to %s as %s ...',
          \ client.apiname,
          \ empty(username)
          \   ? 'an anonymous user'
          \   : username,
          \))
  endif

  let res = client.post('gists', gist)
  if res.status == 201
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:J.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_modified = 0
    let gist._last_modified = s:G.parse_response_last_modified(res)
    call client.content_cache.set(gist.id, gist)
    " TODO
    " Update cached entries of the gist
    return gist
  endif
  " throw an API exception
  call gista#api#throw_api_exception(res)
endfunction " }}}
function! gista#api#gists#patch(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'cache': 0,
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

  " Create a partial_gist instance used for PATCH
  let gist = gista#api#gists#cache#patch(a:gistid, options)
  if options.cache
    return gist
  endif

  let partial_gist = {
        \ 'description': gist.description,
        \ 'files': {},
        \}
  for [filename, content] in items(gist.files)
    if empty(content)
      let partial_gist.files[filename] = s:J.null
    else
      let partial_gist.files[filename] = s:D.pick(content, [
            \ 'filename',
            \ 'content',
            \])
    endif
    unlet content
  endfor

  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Patching a gist %s to %s as %s...',
          \ gist.id,
          \ client.apiname,
          \ username,
          \))
  endif
  let res = client.patch('gists/' . gist.id, partial_gist)
  if res.status == 200
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:J.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_modified = 0
    let gist._last_modified = s:G.parse_response_last_modified(res)
    call client.content_cache.set(gist.id, gist)
    " TODO
    " Update cached entries of the gist
    return gist
  endif
  " throw an API exception
  call gista#api#throw_api_exception(res)
endfunction " }}}
function! gista#api#gists#delete(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'cache': 0,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Deleting a gist cannot be performed as an anonymous user',
          \)
  endif

  let gist = gista#api#gists#cache#delete(a:gistid, options)
  if options.cache
    return
  endif
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Deleting a gist %s in %s as %s...',
          \ gist.id,
          \ client.apiname,
          \ username,
          \))
  endif
  let res = client.delete('gists/' . gist.id)
  if res.status != 204
    call gista#api#throw_api_exception(res)
  endif
endfunction " }}}
function! gista#api#gists#content(gist, filename, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'cache': 1,
        \}, get(a:000, 0, {})
        \)
  let content = gista#api#gists#cache#content(a:gist, a:filename, options)
  if options.cache && !content.truncated
    return content
  endif
  " request the file content if the content is truncated
  let filename = content.filename
  let file = get(a:gist.files, filename, {})
  let client = gista#api#get_current_client()
  let res = client.get(file.raw_url)
  if res.status == 200
    let file.truncated = 0
    let file.content = res.content
    let a:gist.files[filename] = file
    call client.content_cache.set(a:gist.id, a:gist)
    return {
          \ 'filename': filename,
          \ 'content': split(file.content, '\r\?\n'),
          \ 'truncated': 0,
          \}
  endif
  call gista#api#throw_api_exception(res)
endfunction " }}}


function! gista#api#gists#is_fetched(gist_or_entry) abort " {{{
  return get(a:gist_or_entry, '_gista_fetched')
endfunction " }}}
function! gista#api#gists#is_modified(gist_or_entry) abort " {{{
  return get(a:gist_or_entry, '_gista_modified')
endfunction " }}}

" Configure variables
call gista#define_variables('api#gists', {
      \ 'list_default_lookup': '',
      \ 'post_default_public': 1,
      \ 'post_interactive_description': 1,
      \ 'post_allow_empty_description': 0,
      \ 'patch_interactive_description': 1,
      \ 'patch_allow_empty_description': 0,
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
