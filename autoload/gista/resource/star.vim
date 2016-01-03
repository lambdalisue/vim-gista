let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')

let s:CACHE_DISABLED = 0
let s:CACHE_ENABLED = 1
let s:CACHE_FORCED = 2

function! gista#resource#star#get(gistid, ...) abort
  let options = get(a:000, 0, {})
  let client = gista#client#get()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Checking if a gist is starred cannot be performed as an anonymous user',
          \)
  endif

  let gist = gista#resource#gists#get(a:gistid, {
        \ 'cache': s:CACHE_FORCED,
        \})
  redraw
  call gista#util#prompt#echo(printf(
        \ 'Requesting if a gist %s in %s is starred ...',
        \ a:gistid, client.apiname,
        \))

  let url = printf('gists/%s/star', a:gistid)
  let res = client.get(url)
  redraw
  if res.status == 204
    return 1
  elseif res.status == 404
    return 0
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#star#put(gistid, ...) abort
  let options = get(a:000, 0, {})
  let client = gista#client#get()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Star a gist cannot be performed as an anonymous user',
          \)
  endif

  let gist = gista#resource#gists#get(a:gistid, {
        \ 'cache': s:CACHE_FORCED,
        \})
  redraw
  call gista#util#prompt#echo(printf(
        \ 'Star a gist %s in %s ...',
        \ a:gistid, client.apiname,
        \))

  let url = printf('gists/%s/star', a:gistid)
  let headers = { 'Content-Length': 0 }
  let res = client.put(url, {}, headers)
  redraw
  if res.status == 204
    call gista#resource#gists#_add_entry_cache(client, gist, [
          \ username . '/starred',
          \])
    let starred_cache = client.starred_cache.get(username, {})
    let starred_cache[gist.id] = 1
    call client.starred_cache.set(username, starred_cache)
    return
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#star#delete(gistid, ...) abort
  let options = get(a:000, 0, {})
  let client = gista#client#get()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Unstar a gist cannot be performed as an anonymous user',
          \)
  endif

  let gist = gista#resource#gists#get(a:gistid, {
        \ 'cache': s:CACHE_FORCED,
        \})
  redraw
  call gista#util#prompt#echo(printf(
        \ 'Unstar a gist %s in %s ...',
        \ a:gistid, client.apiname,
        \))

  let url = printf('gists/%s/star', a:gistid)
  let res = client.delete(url)
  redraw
  if res.status == 204
    call gista#resource#gists#_remove_entry_cache(client, gist, [
          \ username . '/starred',
          \])
    let starred_cache = client.starred_cache.get(username, {})
    silent! unlet starred_cache[gist.id]
    call client.starred_cache.set(username, starred_cache)
    return
  endif
  call gista#client#throw(res)
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
