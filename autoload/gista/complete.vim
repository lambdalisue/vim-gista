let s:save_cpo = &cpo
set cpo&vim

function! gista#complete#apiname(arglead, cmdline, cursorpos, ...) abort " {{{
  let apinames = gista#api#registered_apinames()
  return filter(apinames, 'v:val =~# "^" . a:arglead')
endfunction " }}}
function! gista#complete#username(arglead, cmdline, cursorpos, ...) abort " {{{
  let options = extend({
        \ 'apiname': gista#api#get_current_apiname(),
        \}, get(a:000, 0, {}),
        \)
  let apiname = gista#util#validate#silently(
        \ 'gista#api#get_apiname',
        \ options.apiname
        \)
  if !empty(apiname)
    let client = gista#api#client(options)
    let usernames = client.token_cache.keys()
  else
    let usernames = uniq([
          \ gista#api#get_current_username(),
          \ g:gista#api#default_username,
          \])
  endif
  return filter(usernames, '!empty(v:val) && v:val =~# "^" . a:arglead')
endfunction " }}}
function! gista#complete#gistid(arglead, cmdline, cursorpos, ...) abort " {{{
  let options = extend({
        \ 'apiname': gista#api#get_current_apiname(),
        \ 'username': gista#api#get_current_username(),
        \}, get(a:000, 0, {}),
        \)
  let apiname = gista#util#validate#silently(
        \ 'gista#api#get_apiname',
        \ options.apiname
        \)
  let username = gista#util#validate#silently(
        \ 'gista#api#get_username',
        \ options.username
        \)
  if !empty(apiname) && !empty(username)
    let client = gista#api#client(options)
    let entries = client.entry_cache.get(username, [])
    let gistids = map(copy(entries), 'v:val.id')
  else
    let gistids = []
  endif
  return filter(gistids, 'v:val =~# "^" . a:arglead')
endfunction " }}}
function! gista#complete#filename(arglead, cmdline, cursorpos, ...) abort " {{{
  let options = extend({
        \ 'apiname': gista#api#get_current_apiname(),
        \ 'gistid': gista#api#get#get_current_gistid(),
        \}, get(a:000, 0, {}),
        \)
  let apiname = gista#util#validate#silently(
        \ 'gista#api#get_apiname',
        \ options.apiname
        \)
  let gistid = gista#util#validate#silently(
        \ 'gista#api#get#get_gistid',
        \ options.gistid
        \)
  if !empty(apiname) && !empty(gistid)
    let client = gista#api#client(options)
    let gist = client.content_cache.get(gistid)
    let filenames = keys(gist.files)
  else
    let filenames = []
  endif
  return filter(filenames, 'v:val =~# "^" . a:arglead')
endfunction " }}}
function! gista#complete#lookup(arglead, cmdline, cursorpos, ...) abort " {{{
  let options = extend({
        \ 'username': gista#api#get_current_username(),
        \}, get(a:000, 0, {}),
        \)
  let username = gista#util#validate#silently(
        \ 'gista#api#get_username',
        \ options.username
        \)
  let candidates = [
        \ g:gista#api#list#default_lookup,
        \ username,
        \ g:gista#api#default_username,
        \ 'starred',
        \]
  let candidates = extend(
        \ candidates,
        \ gista#complete#username(
        \   a:arglead, a:cmdline, a:cursorpos, options
        \ )
        \)
  let candidates = extend(
        \ candidates,
        \ ['public']
        \)
  return filter(
        \ uniq(candidates),
        \ '!empty(v:val) && v:val =~# "^" . a:arglead'
        \)
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
