let s:V = gista#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:JSON = s:V.import('Web.JSON')
let s:GitHub = s:V.import('Web.API.GitHub')

let s:CACHE_DISABLED = 0
let s:CACHE_ENABLED  = 1
let s:CACHE_FORCED   = 2

function! gista#resource#remote#is_modified(lhs, rhs) abort
  " NOTE:
  " updated_at after PATCH sometime differ from GET thus check difference
  " betweeh cached and fetched except updated_at/_gista_last_modified fields
  let unnecessary_fields = [
        \ 'owner',
        \ 'updated_at',
        \ '_gista_fetched',
        \ '_gista_modified',
        \ '_gista_last_modified',
        \]
  let lhs = s:Dict.omit(a:lhs, unnecessary_fields)
  let rhs = s:Dict.omit(a:rhs, unnecessary_fields)
  return lhs != rhs
endfunction

function! gista#resource#remote#get(gistid, ...) abort
  let options = extend({
        \ 'cache': s:CACHE_ENABLED,
        \}, get(a:000, 0, {})
        \)
  let local_gist = gista#resource#local#get(a:gistid, options)
  if options.cache == s:CACHE_FORCED
        \ || (options.cache != s:CACHE_DISABLED && local_gist._gista_fetched)
    redraw
    return extend(copy(local_gist), { '_gista_modified': 0 })
  endif

  " From API
  let client = gista#client#get()
  call gista#util#prompt#indicate(options, printf(
        \ 'Fetching a gist %s in %s ...',
        \ a:gistid, client.apiname,
        \))
  let url = 'gists/' . a:gistid
  let res = client.get(url, {}, {
        \ 'If-Modified-Since': local_gist._gista_last_modified,
        \})
  redraw
  if res.status == 304
    " the content is not modified since the last request
    return extend(copy(local_gist), { '_gista_modified': 0 })
  elseif res.status == 200
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:JSON.decode(res.content)
    let gist = res.content
    " Note:
    " gistid might contain version info thus overwrite it
    let gist.id = a:gistid
    let gist._gista_fetched = 1
    let gist._gista_last_modified = s:GitHub.parse_response_last_modified(res)
    call gista#util#prompt#indicate(options, printf(
          \ 'Updating local caches of a gist %s in %s ...',
          \ a:gistid, client.apiname,
          \))
    call gista#resource#local#append_gist(gist)
    call gista#resource#local#update_index_entry(gist)
    redraw
    return extend(copy(gist), {
          \ '_gista_modified': gista#resource#remote#is_modified(
          \   local_gist, gist
          \ ),
          \})
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#remote#file(gist, filename, ...) abort
  let options = extend({
        \ 'cache': s:CACHE_ENABLED,
        \}, get(a:000, 0, {})
        \)
  let file = gista#resource#local#file(a:gist, a:filename, options)
  if options.cache == s:CACHE_FORCED ||
        \ (options.cache != s:CACHE_DISABLED && !file.truncated)
    redraw
    return file
  endif

  " From API
  let client = gista#client#get()
  let res = client.get(file.raw_url, {}, {
        \ 'Content-Type': 'text/plain',
        \})
  if res.status == 200
    let file.truncated = 0
    let file.content = res.content
    let a:gist.files[a:filename] = file
    call gista#util#prompt#indicate(options, printf(
          \ 'Updating a local cache of a gist %s in %s ...',
          \ a:gist.id, client.apiname,
          \))
    call gista#resource#local#append_gist(a:gist)
    return file
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#remote#list(lookup, ...) abort
  let options = extend({
        \ 'cache': s:CACHE_ENABLED,
        \ 'since': 1,
        \ 'python': has('python') || has('python3'),
        \}, get(a:000, 0, {})
        \)
  let local_index = gista#resource#local#list(a:lookup, options)
  if options.cache == s:CACHE_FORCED ||
        \ (options.cache != s:CACHE_DISABLED && local_index._gista_fetched)
    redraw
    return local_index
  endif

  " From API
  let client = gista#client#get()
  let username = client.get_authorized_username()
  let since = type(options.since) == type(0)
        \ ? options.since
        \   ? empty(local_index.entries)
        \     ? ''
        \     : local_index.entries[0].updated_at
        \   : ''
        \ : options.since
  let url = ''
  if a:lookup ==# 'public'
    let url = 'gists/public'
  elseif !empty(username) && a:lookup ==# username
    let url = 'gists'
  elseif !empty(username) && a:lookup ==# username . '/starred'
    let url = 'gists/starred'
  elseif !empty(a:lookup)
    let url = printf('users/%s/gists', a:lookup)
  else
    call gista#throw(printf(
          \ 'Unknown lookup "%s" is specified',
          \ a:lookup,
          \))
  endif
  let indicator = printf(
        \ 'Requesting gists of %s in %s %%%%(page)d/%%(page_count)d ...',
        \ a:lookup, client.apiname,
        \)
  let entries = client.retrieve({
        \ 'url': url,
        \ 'param': {
        \   'direction': 'desc',
        \   'sort': 'updated',
        \   'since': since,
        \ },
        \ 'indicator': indicator,
        \ 'python': options.python,
        \})
  call gista#util#prompt#indicate(options, printf(
        \ 'Updating local caches of gists of %s in %s ...',
        \ a:lookup, client.apiname,
        \))
  call gista#resource#local#remove_gists(map(copy(entries), 'v:val.id'))
  let index = empty(since) || a:lookup ==# 'public'
        \ ? gista#resource#local#assign_index_entries(a:lookup, entries)
        \ : gista#resource#local#append_index_entries(a:lookup, entries)
  if a:lookup ==# username . '/starred'
    let starred_cache = {}
    for entry in entries
      let starred_cache[entry.id] = 1
    endfor
    call client.starred_cache.set(username, starred_cache)
  endif
  redraw
  return index
endfunction
function! gista#resource#remote#post(filenames, contents, ...) abort
  let options = extend({
        \ 'description': '',
        \ 'public': 0,
        \}, get(a:000, 0, {})
        \)
  let client   = gista#client#get()

  " Create a gist instance
  let gist = {
        \ 'description': options.description,
        \ 'public': options.public ? s:JSON.true : s:JSON.false,
        \ 'files': {},
        \}
  let counter = 1
  for [filename, content] in s:List.zip(a:filenames, a:contents)
    if empty(filename)
      let filename = printf('gista-file%d', counter)
      let counter += 1
    endif
    let gist.files[filename] = content
  endfor

  call gista#util#prompt#indicate(options, printf(
        \ 'Posting contents to create a new gist in %s ...',
        \ client.apiname,
        \))
  let res = client.post('gists', gist)
  redraw
  if res.status == 201
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:JSON.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_last_modified = s:GitHub.parse_response_last_modified(res)
    call gista#util#prompt#indicate(options, printf(
          \ 'Updating local caches of a gist %s in %s ...',
          \ gist.id, client.apiname,
          \))
    call gista#resource#local#append_gist(gist)
    call gista#resource#local#append_index_entry(gist)
    redraw
    return gist
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#remote#patch(gistid, ...) abort
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
    call gista#throw(
          \ 'Patching a gist cannot be performed as an anonymous user',
          \)
  endif

  " Check if a remote content of a gist is modified
  let gist = gista#resource#remote#get(a:gistid, {
        \ 'cache': options.force ? s:CACHE_FORCED : s:CACHE_DISABLED,
        \})
  if !options.force && gist._gista_modified
    call gista#throw(printf(
          \ 'A remote content of a gist %s in %s is modified from last access.',
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
  for [filename, content] in s:List.zip(options.filenames, options.contents)
    if empty(content)
      let partial.files[filename] = s:JSON.null
    else
      let partial.files[filename] = s:Dict.pick(content, [
            \ 'filename',
            \ 'content',
            \])
    endif
  endfor

  call gista#util#prompt#indicate(options, printf(
        \ 'Patching contents to a gist %s in %s ...',
        \ gist.id, client.apiname,
        \))
  let url = 'gists/' . a:gistid
  let res = client.patch(url, partial)
  redraw
  if res.status == 200
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:JSON.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_last_modified = s:GitHub.parse_response_last_modified(res)
    call gista#util#prompt#indicate(options, printf(
          \ 'Updating local caches of a gist %s in %s ...',
          \ gist.id, client.apiname,
          \))
    call gista#resource#local#append_gist(gist)
    call gista#resource#local#update_index_entry(gist)
    redraw
    return gist
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#remote#delete(gistid, ...) abort
  let options = extend({
        \ 'force': 0,
        \}, get(a:000, 0, {})
        \)
  let client   = gista#client#get()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#throw(
          \ 'Deleting a gist cannot be performed as an anonymous user',
          \)
  endif

  " Check if a remote content of a gist is modified
  let gist = gista#resource#remote#get(a:gistid, {
        \ 'cache': options.force ? s:CACHE_FORCED : s:CACHE_DISABLED,
        \})
  if !options.force && get(gist, '_gista_modified', 1)
    call gista#throw(printf(
          \ 'A remote content of a gist %s in %s is modified from last access.',
          \ a:gistid, client.apiname,
          \))
  endif

  call gista#util#prompt#indicate(options, printf(
        \ 'Deleting a gist %s in %s ...',
        \ a:gistid, client.apiname,
        \))
  let url = 'gists/' . a:gistid
  let res = client.delete(url)
  redraw
  if res.status == 204
    call gista#util#prompt#indicate(options, printf(
          \ 'Updating caches of a gist %s in %s ...',
          \ a:gistid, client.apiname,
          \))
    call gista#resource#local#remove_gist(a:gistid)
    call gista#resource#local#remove_index_entry(a:gistid)
    redraw
    return
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#remote#star(gistid, ...) abort
  let options = get(a:000, 0, {})
  let client = gista#client#get()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#throw(
          \ 'Star a gist cannot be performed as an anonymous user',
          \)
  endif

  call gista#util#prompt#indicate(options, printf(
        \ 'Star a gist %s in %s ...',
        \ a:gistid, client.apiname,
        \))
  let url = printf('gists/%s/star', a:gistid)
  let headers = { 'Content-Length': 0 }
  let res = client.put(url, {}, headers)
  redraw
  if res.status == 204
    let gist = gista#resource#local#get(a:gistid)
    call gista#resource#local#append_index_entry(gist, {
          \ 'lookups': [ username . '/starred' ],
          \})
    let starred_cache = client.starred_cache.get(username, {})
    let starred_cache[a:gistid] = 1
    call client.starred_cache.set(username, starred_cache)
    return
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#remote#unstar(gistid, ...) abort
  let options = get(a:000, 0, {})
  let client = gista#client#get()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#throw(
          \ 'Unstar a gist cannot be performed as an anonymous user',
          \)
  endif

  call gista#util#prompt#indicate(options, printf(
        \ 'Unstar a gist %s in %s ...',
        \ a:gistid, client.apiname,
        \))
  let url = printf('gists/%s/star', a:gistid)
  let res = client.delete(url)
  redraw
  if res.status == 204
    call gista#resource#local#remove_index_entry(a:gistid, {
          \ 'lookups': [ username . '/starred' ],
          \})
    let starred_cache = client.starred_cache.get(username, {})
    silent! unlet starred_cache[a:gistid]
    call client.starred_cache.set(username, starred_cache)
    return
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#remote#fork(gistid, ...) abort
  let options = get(a:000, 0, {})
  let client = gista#client#get()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#throw(
          \ 'Forking a gist cannot be performed as an anonymous user',
          \)
  endif

  call gista#util#prompt#indicate(options, printf(
        \ 'Forking a gist %s in %s ...',
        \ a:gistid, client.apiname,
        \))
  let url = printf('gists/%s/forks', a:gistid)
  let res = client.post(url)
  redraw
  if res.status == 201
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:JSON.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_last_modified = s:GitHub.parse_response_last_modified(res)
    call gista#util#prompt#indicate(options, printf(
          \ 'Updating local caches of a gist %s in %s ...',
          \ gist.id, client.apiname,
          \))
    call gista#resource#local#append_gist(gist)
    call gista#resource#local#append_index_entry(gist)
    redraw
    return gist
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#remote#commits(gistid, ...) abort
  let options = get(a:000, 0, {})
  let client = gista#client#get()

  call gista#util#prompt#indicate(options, printf(
        \ 'Fetching commits of a gist %s in %s ...',
        \ a:gistid, client.apiname,
        \))
  let url = printf('gists/%s/commits', a:gistid)
  let res = client.get(url)
  redraw
  if res.status == 200
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:JSON.decode(res.content)
    let commits = res.content
    return commits
  endif
  call gista#client#throw(res)
endfunction
