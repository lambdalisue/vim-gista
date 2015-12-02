let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:J = s:V.import('Web.JSON')
let s:current_gistid = ''

function! s:ask_gistid(...) abort " {{{
  redraw
  return gista#util#prompt#ask(
        \ 'Please input a gist id: ', '',
        \ 'customlist,gista#complete#gistid',
        \)
endfunction " }}}
function! s:set_current_gistid(value) abort " {{{
  let s:current_gistid = a:value
endfunction " }}}

function! gista#api#get#get_gistid(gistid) abort " {{{
  let gistid = empty(a:gistid)
        \ ? s:ask_gistid()
        \ : a:gistid
  call gista#validate#gistid(gistid)
  return gistid
endfunction " }}}
function! gista#api#get#get_current_gistid() abort " {{{
  return s:current_gistid
endfunction " }}}
function! gista#api#get#call(client, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'gistid': '',
        \ 'fresh': 0,
        \}, get(a:000, 0, {})
        \)
  let anonymous = gista#api#get_current_anonymous()
  let gistid = gista#api#get#get_gistid(options.gistid)
  if a:client.content_cache.has(gistid)
    let content = a:client.content_cache.get(gistid)
    if options.fresh && !get(content, '_gista_partial')
      if get(content, '_gista_modified')
        if !gista#util#prompt#asktf(join([
            \ 'The content of the gist in the cache seems be modified.',
            \ 'Are you sure you want to overwrite the changes? ',
            \], "\n"))
          call s:set_current_gistid(gistid)
          return content
        endif
      endif
    elseif !get(content, '_gista_partial')
      call s:set_current_gistid(gistid)
      return content
    endif
  endif
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Requesting a gist "%s" in %s%s ...',
          \ gistid,
          \ a:client.name,
          \ anonymous
          \   ? ' as an anonymous user'
          \   : ''
          \))
  endif
  let url = printf('gists/%s', gistid)
  let res = a:client.get(url, {}, {}, {
        \ 'verbose': options.verbose,
        \ 'anonymous': anonymous,
        \})
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:J.decode(res.content)
  if res.status != 200
    call gista#util#prompt#throw(
          \ printf('%s: %s', res.status, res.statusText),
          \ get(res.content, 'message', ''),
          \)
  endif
  call s:set_current_gistid(gistid)
  call a:client.content_cache.set(gistid, res.content)
  return res.content
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
