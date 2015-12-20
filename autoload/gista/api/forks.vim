let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:J = s:V.import('Web.JSON')

function! gista#api#fork#post(gistid, ...) abort " {{{
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
          \ 'Forking a gist "%s" in %s ...',
          \ gist.id,
          \ client.apiname,
          \))
  endif

  let url = printf('gists/%s/forks', gist.id)
  let res = client.post(url, {}, {}, {
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
function! gista#api#fork#list(gistid, ...) abort " {{{
  call gista#util#prompt#throw(
        \ 'Not implemented yet'
        \)
endfunction " }}}

" Configure variables
call gista#define_variables('api#fork', {
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
