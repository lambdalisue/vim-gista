let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')
let s:D = s:V.import('Data.Dict')
let s:J = s:V.import('Web.JSON')
let s:G = s:V.import('Web.API.GitHub')

function! gista#api#gists#get_gist_owner(gist) abort
  return get(get(a:gist, 'owner', {}), 'login', '')
endfunction
function! gista#api#gists#get_pseudo_entry_file() abort
  return {
        \ 'size': 0,
        \ 'type': '',
        \ 'language': '',
        \}
endfunction
function! gista#api#gists#get_pseudo_gist_file() abort
  return extend(gista#api#gists#get_pseudo_entry_file(), {
        \ 'truncated': 1,
        \ 'content': '',
        \ 'raw_url': '',
        \})
endfunction
function! gista#api#gists#get_pseudo_entry(gistid) abort
  return {
        \ 'id': a:gistid,
        \ 'description': '',
        \ 'public': 0,
        \ 'files': {},
        \ 'created_at': '',
        \ 'updated_at': '',
        \ '_gista_fetched': 0,
        \ '_gista_modified': 0,
        \}
endfunction
function! gista#api#gists#get_pseudo_gist(gistid) abort
  return extend(gista#api#gists#get_pseudo_entry(a:gistid), {
        \ '_gista_last_modified': '',
        \})
endfunction
function! gista#api#gists#get_pseudo_index() abort
  return {
        \ 'entries': [],
        \ '_gista_fetched': 0,
        \}
endfunction

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
  redraw
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
            \ 'Updating cache of a gist %s in %s ...',
            \ gist.id, client.apiname,
            \))
    endif
    call gista#api#gists#cache#add_gist(gist)
    call gista#api#gists#cache#replace_index_entry(gist)
    redraw
    return gist
  endif
  call gista#api#throw_api_exception(res)
endfunction
function! gista#api#gists#file(gist, filename, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'cache': 1,
        \}, get(a:000, 0, {})
        \)
  let file = gista#api#gists#cache#file(a:gist, a:filename)
  if options.cache && !file.truncated
    return file
  endif
  let client = gista#api#get_current_client()
  let res = client.get(file.raw_url)
  if res.status == 200
    let file.truncated = 0
    let file.content = res.content
    let a:gist.files[a:filename] = file
    call gista#api#gists#cache#add_gist(a:gist)
    return file
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
  let index = gista#api#gists#cache#list(a:lookup, options)
  if options.cache && index._gista_fetched
    return index
  endif
  " assign page/since/last_page
  let client = gista#api#get_current_client()
  let since = type(options.since) == type(0)
        \ ? options.since
        \   ? empty(index.entries)
        \     ? ''
        \     : index.entries[0].updated_at
        \   : ''
        \ : options.since
  " find a corresponding url
  let username = client.get_authorized_username()
  if a:lookup ==# 'public'
    let url = 'gists/public'
  elseif !empty(username) && a:lookup ==# username
    let url = 'gists'
  elseif !empty(username) && a:lookup ==# username . '/starred'
    let url = 'gists/starred'
  elseif !empty(a:lookup)
    let url = printf('users/%s/gists', a:lookup)
  endif
  " fetch entries
  let indicator = printf(
        \ 'Requesting gists of %s in %s as %s %%%%(page)d/%%(page_count)d ...',
        \ a:lookup,
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
    call gista#util#prompt#echo('Updating entry/gist caches of gists ...')
  endif
  if empty(since) || a:lookup ==# 'public'
    call gista#api#gists#cache#replace_index_entries(fetched_entries, a:lookup, {
          \ 'fetched': 1,
          \})
  else
    call gista#api#gists#cache#update_index_entries(fetched_entries, a:lookup, {
          \ 'fetched': 1,
          \})
  endif
  call gista#api#gists#cache#remove_gists(fetched_entries)
  " TODO
  " Assign 'Last-Modified' correctly to handle 304 Not Modified
  redraw
  return client.index_cache.get(a:lookup)
endfunction
function! gista#api#gists#post(filenames, contents, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'description': '',
        \ 'public': 0,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()

  " Create a gist instance
  let gist = {
        \ 'description': options.description,
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
  redraw
  if res.status == 201
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:J.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_modified = 0
    let gist._gista_last_modified = s:G.parse_response_last_modified(res)
    call gista#api#gists#cache#add_gist(gist)
    call gista#api#gists#cache#add_index_entry(gist)
    return gist
  endif
  call gista#api#throw_api_exception(res)
endfunction
function! gista#api#gists#patch(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'cache': 0,
        \ 'description': '',
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
  redraw
  if res.status == 200
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:J.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_modified = 0
    let gist._gista_last_modified = s:G.parse_response_last_modified(res)
    call gista#api#gists#cache#add_gist(gist)
    call gista#api#gists#cache#update_index_entry(gist)
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
  redraw
  if res.status == 204
    call gista#api#gists#cache#remove_gist(gist)
    call gista#api#gists#cache#remove_index_entry(gist)
  endif
  call gista#api#throw_api_exception(res)
endfunction

" Configure variables
call gista#define_variables('api#gists', {})

let &cpo = s:save_cpo
unlet! s:save_cpo
