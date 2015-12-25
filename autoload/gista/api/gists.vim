let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')
let s:D = s:V.import('Data.Dict')
let s:J = s:V.import('Web.JSON')
let s:G = s:V.import('Web.API.GitHub')

" Resource API
function! gista#api#gists#get(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'cache': 1,
        \}, get(a:000, 0, {})
        \)
  let gist = gista#api#gists#cache#get(a:gistid, options)
  if !options.cache && gist._gista_modified
    let ret = gista#util#prompt#ask(printf(join([
          \ 'A gist %s seems to have unposted changes and fetching might ',
          \ 'overwrite this changes.',
          \ 'Are you sure to continue?',
          \ ]), gist.id))
    if ret == 0
      call gista#util#prompt#throw('Cancel')
    endif
  elseif options.cache && gist._gista_fetched
    return gist
  endif

  let gistid = gist.id
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Fetching a gist %s in %s as %s ...',
          \ gistid,
          \ client.apiname,
          \ empty(username)
          \   ? 'an anonymous user'
          \   : username,
          \))
  endif
  let headers = {
        \ 'If-Modified-Since': gist._gista_last_modified,
        \}
  let res = client.get('gists/' . gistid, {}, headers)
  if res.status == 304
    " the content is not modified since the last request
    return gist
  elseif res.status == 200
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:J.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_modified = 0
    let gist._gista_last_modified = s:G.parse_response_last_modified(res)
    if options.verbose
      redraw
      call gista#util#prompt#echo(printf(
            \ 'Updating a cache of a gist %s in %s ...',
            \ gist.id, client.apiname,
            \))
    endif
    call client.content_cache.set(gist.id, gist)
    call gista#api#gists#cache#update_entry(gist)
    return gist
  endif
  call gista#api#throw_api_exception(res)
endfunction
function! gista#api#gists#list(lookup, ...) abort
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
        \ ? options.since
        \   ? empty(content.entries)
        \     ? ''
        \     : content.entries[0].updated_at
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
  if options.verbose
    redraw
    call gista#util#prompt#echo('Updating entry/content caches of gists ...')
  endif
  call gista#api#gists#cache#add_entries(fetched_entries, {
        \ 'lookups': [lookup],
        \ 'replace': empty(since) || lookup ==# 'public',
        \})
  call gista#api#gists#cache#delete_contents(fetched_entries)
  " TODO
  " Assign 'Last-Modified' correctly to handle 304 Not Modified
  let content = client.entry_cache.get(lookup)
  return content
endfunction
function! gista#api#gists#post(filenames, contents, ...) abort
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
    let gist._gista_last_modified = s:G.parse_response_last_modified(res)
    call client.content_cache.set(gist.id, gist)
    call gista#api#gists#cache#add_entry(gist, { 'replace': 0 })
    return gist
  endif
  call gista#api#throw_api_exception(res)
endfunction
function! gista#api#gists#patch(gistid, ...) abort
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
          \ 'Patching a gist %s in %s as %s...',
          \ gist.id, client.apiname, username,
          \))
  endif
  let res = client.patch('gists/' . gist.id, partial_gist)
  if res.status == 200
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:J.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_modified = 0
    let gist._gista_last_modified = s:G.parse_response_last_modified(res)
    call client.content_cache.set(gist.id, gist)
    call gista#api#gists#cache#add_entry(gist)
    return gist
  endif
  call gista#api#throw_api_exception(res)
endfunction
function! gista#api#gists#delete(gistid, ...) abort
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
          \ gist.id, client.apiname, username,
          \))
  endif
  let res = client.delete('gists/' . gist.id)
  if res.status == 204
    call client.content_cache.remove(gist.id)
    call gista#api#gists#cache#delete_entry(gist)
  endif
  call gista#api#throw_api_exception(res)
endfunction
function! gista#api#gists#content(gist, filename, ...) abort
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
endfunction

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
