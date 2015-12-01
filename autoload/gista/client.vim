let s:save_cpo = &cpoptions
set cpoptions&vim

let s:V = gista#vital()
let s:D = s:V.import('Data.Dict')
let s:C = s:V.import('System.Cache')
let s:G = s:V.import('Web.API.GitHub')

function! s:get_client_cache() abort " {{{
  if !exists('s:client_cache')
    let s:client_cache = s:C.new('memory')
  endif
  return s:client_cache
endfunction " }}}
function! s:get_token_cache(baseurl) abort " {{{
  let name = printf('token:%s', a:baseurl)
  let cache = gista#util#get_cache(name)
  return cache
endfunction " }}}

function! gista#client#new(baseurl) abort " {{{
  let token_cache = s:get_token_cache(a:baseurl)
  let client = s:G.new({
        \ 'baseurl': a:baseurl,
        \ 'authorize_scope': ['gist'],
        \ 'authorize_note': g:gista#client#authorize_note,
        \ 'authorize_note_url': g:gista#client#authorize_note_url,
        \ 'token_cache': token_cache,
        \})
  return client
endfunction " }}}
function! gista#client#get(baseurl) abort " {{{
  let client_cache = s:get_client_cache()
  if !client_cache.has(a:baseurl)
    call client_cache.set(a:baseurl, gista#client#new(a:baseurl))
  endif
  return client_cache.get(a:baseurl)
endfunction " }}}
function! gista#client#get_baseurl(baseurl_or_alias) abort " {{{
  let baseurl_or_alias = empty(a:baseurl_or_alias)
        \ ? g:gista#client#baseurl
        \ : a:baseurl_or_alias
  if baseurl_or_alias =~# 'https?://'
    return baseurl_or_alias
  elseif has_key(g:gista#client#baseurl_aliases, basurl_or_alias)
    return g:gista#client#baseurl_aliases[baseurl_or_alias]
  endif
  call gista#prompt#error(printf(
        \ 'No baseurl alias for "%s" is found in "%s"',
        \ baseurl_or_alias,
        \ 'g:client#baseurl_aliases',
        \))
  return ''
endfunction " }}}
function! gista#client#get_alias(baseurl_or_alias) abort " {{{
  let reverse_aliases = s:D.swap(g:gista#client#baseurl_aliases)
  let baseurl_or_alias = empty(a:baseurl_or_alias)
        \ ? g:gista#client#baseurl
        \ : a:baseurl_or_alias
  if baseurl_or_alias =~# 'https?://'
    return get(reverse_aliases, baseurl_or_alias, baseurl_or_alias)
  else
    return baseurl_or_alias
  endif
endfunction " }}}
function! gista#client#login_required(client, ...) abort " {{{
  let options  = get(a:000, 0, {})
  let username = get(options, 'username', '')
  if a:client.login(username, s:D.pick(options, ['force']))
    return 1
  endif
  " login failed
  let baseurl = gista#client#get_baseurl(get(options, 'baseurl', ''))
  let alias = gista#client#get_alias(baseurl)
  call gista#prompt#warn(printf(
        \ 'Failed to login as "%s" to gist API on "%s".',
        \ username, alias,
        \))
  return 0
endfunction " }}}


call gista#util#init('client', {
      \ 'baseurl': 'https://api.github.com',
      \ 'baseurl_aliases': {
      \   'GitHub': 'https://api.github.com',
      \ },
      \})
let &cpoptions = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
