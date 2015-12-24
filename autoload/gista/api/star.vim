let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')

function! gista#api#star#get(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Checking if a gist is starred cannot be performed as an anonymous user',
          \)
  endif

  let gist = gista#api#gists#get(a:gistid, options)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Requesting if a gist %s in %s is starred ...',
          \ gist.id,
          \ client.apiname,
          \))
  endif

  let url = printf('gists/%s/star', gist.id)
  let res = client.get(url)
  if res.status == 204
    return 1
  elseif res.status == 404
    return 0
  endif
  call gista#api#throw_api_exception(res)
endfunction " }}}
function! gista#api#star#put(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Star a gist cannot be performed as an anonymous user',
          \)
  endif

  let gist = gista#api#gists#get(a:gistid, options)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Star a gist %s in %s ...',
          \ gist.id,
          \ client.apiname,
          \))
  endif

  let url = printf('gists/%s/star', gist.id)
  let headers = { 'Content-Length': 0 }
  let res = client.put(url, {}, headers)
  if res.status == 204
    return
  else
    call gista#api#throw_api_exception(res)
  endif
endfunction " }}}
function! gista#api#star#delete(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Unstar a gist cannot be performed as an anonymous user',
          \)
  endif

  let gist = gista#api#gists#get(a:gistid, options)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Unstar a gist %s in %s ...',
          \ gist.id,
          \ client.apiname,
          \))
  endif

  let url = printf('gists/%s/star', gist.id)
  let res = client.delete(url)
  if res.status == 204
    return
  endif
  call gista#api#throw_api_exception(res)
endfunction " }}}

" Configure variables
call gista#define_variables('api#star', {})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
