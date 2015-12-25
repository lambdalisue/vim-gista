let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:J = s:V.import('Web.JSON')

function! gista#api#fork#post(gistid, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Forking a gist cannot be performed as an anonymous user',
          \)
  endif

  let gist = gista#api#gists#get(a:gistid, options)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Forking a gist %s in %s ...',
          \ gist.id,
          \ client.apiname,
          \))
  endif

  let url = printf('gists/%s/forks', gist.id)
  let res = client.post(url)
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
  call gista#api#throw_api_exception(res)
endfunction
function! gista#api#fork#list(gistid, ...) abort
  call gista#util#prompt#throw(
        \ 'Not implemented yet'
        \)
endfunction

" Configure variables
call gista#define_variables('api#fork', {})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
