let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:J = s:V.import('Web.JSON')
let s:G = s:V.import('Web.API.GitHub')

let s:CACHE_DISABLED = 0
let s:CACHE_ENABLED = 1
let s:CACHE_FORCED = 2

function! gista#resource#forks#post(gistid, ...) abort
  let options = get(a:000, 0, {})
  let client = gista#client#get()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Forking a gist cannot be performed as an anonymous user',
          \)
  endif

  let gist = gista#resource#gists#get(a:gistid, {
        \ 'cache': s:CACHE_FORCED,
        \})
  redraw
  call gista#util#prompt#echo(printf(
        \ 'Forking a gist %s in %s ...',
        \ a:gistid, client.apiname,
        \))

  let url = printf('gists/%s/forks', a:gistid)
  let res = client.post(url)
  redraw
  if res.status == 201
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? {} : s:J.decode(res.content)
    let gist = res.content
    let gist._gista_fetched = 1
    let gist._gista_etag = s:G.parse_response_etag(res)
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Updating caches of a gist %s in %s ...',
          \ gist.id, client.apiname,
          \))
    call gista#resource#gists#_add_gist_cache(client, gist)
    call gists#resource#gists#_add_entry_cache(client, gist, [
          \ username,
          \ gist.public ? 'public' : '',
          \])
    redraw
    return gist
  endif
  call gista#client#throw(res)
endfunction
function! gista#resource#forks#list(gistid, ...) abort
  call gista#util#prompt#throw('Not implemented yet')
endfunction


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
