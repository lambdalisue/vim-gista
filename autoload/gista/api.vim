let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:C = s:V.import('System.Cache')
let s:P = s:V.import('System.Filepath')
let s:D = s:V.import('Data.Dict')
let s:J = s:V.import('Web.JSON')
let s:G = s:V.import('Web.API.GitHub')

let s:registry = {}
let s:current_client = {}

function! s:get_client_cache() abort " {{{
  if !exists('s:client_cache')
    let s:client_cache = s:C.new('memory')
  endif
  return s:client_cache
endfunction " }}} 
function! s:get_token_cache(apiname) abort " {{{
  if !exists('s:token_cache')
    let s:token_cache = s:C.new('memory')
  endif
  if s:token_cache.has(a:apiname)
    return s:token_cache.get(a:apiname)
  endif
  let cache_file = expand(s:P.join(g:gista#api#cache_dir, 'token', a:apiname))
  let token_cache = s:C.new('singlefile', {
        \ 'cache_file': cache_file,
        \ 'autodump': 1,
        \})
  call s:token_cache.set(a:apiname, token_cache)
  return token_cache
endfunction " }}} 
function! s:get_entry_cache(apiname) abort " {{{
  if !exists('s:entry_cache')
    let s:entry_cache = s:C.new('memory')
  endif
  if s:entry_cache.has(a:apiname)
    return s:entry_cache.get(a:apiname)
  endif
  let cache_dir = expand(s:P.join(g:gista#api#cache_dir, 'entry', a:apiname))
  let entry_cache = s:C.new('file', {
        \ 'cache_dir': cache_dir,
        \})
  call s:entry_cache.set(a:apiname, entry_cache)
  return entry_cache
endfunction " }}}
function! s:get_content_cache(apiname) abort " {{{
  if !exists('s:content_cache')
    let s:content_cache = s:C.new('memory')
  endif
  if s:content_cache.has(a:apiname)
    return s:content_cache.get(a:apiname)
  endif
  let cache_dir = expand(s:P.join(g:gista#api#cache_dir, 'content', a:apiname))
  let content_cache = s:C.new('file', {
        \ 'cache_dir': cache_dir,
        \})
  call s:content_cache.set(a:apiname, content_cache)
  return content_cache
endfunction " }}}

function! s:validate_apiname(apiname) abort " {{{
  call gista#util#validate#not_empty(
        \ a:apiname,
        \ 'An API name cannot be empty',
        \)
  call gista#util#validate#exists(
        \ a:apiname, keys(s:registry),
        \ 'An API name "%value" has not been registered yet',
        \)
endfunction " }}}
function! s:get_default_apiname() abort " {{{
  let apiname = g:gista#api#default_apiname
  try
    call s:validate_apiname(apiname)
    return apiname
  catch /^vim-gista: ValidationError/
    call gista#util#prompt#warn(v:exception)
    call gista#util#prompt#warn(
          \ '"GitHub" will be used as a default API name instead',
          \)
    return 'GitHub'
  endtry
endfunction " }}}
function! s:validate_username(username) abort " {{{
  call gista#util#validate#pattern(
        \ a:username, '^[a-zA-Z0-9_\-]\+$',
        \ 'An API username "%value" requires to follow "%pattern"'
        \)
endfunction " }}}
function! s:get_default_username(apiname) abort " {{{
  if type(g:gista#api#default_username) == type('')
    let username = g:gista#api#default_username
  else
    let default = get(g:gista#api#default_username, '_', '')
    let username = get(g:gista#api#default_username, a:apiname, default)
  endif
  if empty(username)
    return ''
  endif
  try
    call s:validate_username(username)
    return username
  catch /^vim-gista: ValidationError/
    call gista#util#prompt#warn(v:exception)
    call gista#util#prompt#warn('An anonymous user is used instead')
    return ''
  endtry
endfunction " }}}

function! s:login(client, username, options) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \}, a:options,
        \)
  call s:validate_username(a:username)
  try
    call a:client.login(a:username, {
          \ 'verbose': options.verbose,
          \})
  catch /^vital: Web.API.GitHub:/
    throw substitute(v:exception, '^vital: Web.API.GitHub:', 'vim-gista:', '')
  endtry
endfunction " }}}
function! s:logout(client, options) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'permanent': 0,
        \}, a:options,
        \)
  try
    call a:client.logout({
          \ 'verbose': options.verbose,
          \ 'permanent': options.permanent,
          \})
  catch /^vital: Web.API.GitHub:/
    throw substitute(v:exception, '^vital: Web.API.GitHub:', 'vim-gista:', '')
  endtry
endfunction " }}}
function! s:new_client(apiname) abort " {{{
  let client = s:G.new({
        \ 'baseurl': s:registry[a:apiname],
        \ 'token_cache': s:get_token_cache(a:apiname),
        \})
  " extend client
  let client.apiname = a:apiname
  let client.entry_cache = s:get_entry_cache(a:apiname)
  let client.content_cache = s:get_content_cache(a:apiname)
  " login if default_username of apiname exists
  let default_username = s:get_default_username(a:apiname)
  if !empty(default_username)
    call s:login(client, default_username, { 'verbose': 1 })
  endif
  return client
endfunction " }}}
function! s:get_client(apiname) abort " {{{
  let client_cache = s:get_client_cache()
  if client_cache.has(a:apiname)
    return client_cache.get(a:apiname)
  endif
  let client = s:new_client(a:apiname)
  call client_cache.set(a:apiname, client)
  return client
endfunction " }}}

function! gista#api#register(apiname, baseurl) abort " {{{
  try
    call gista#util#validate#not_empty(a:apiname,
          \ 'An API name cannot be empty',
          \)
    call gista#util#validate#pattern(
          \ a:apiname, '^[a-zA-Z0-9_\-]\+$',
          \ 'An API name "%value" requires to follow "%pattern"'
          \)
    call gista#util#validate#key_not_exists(
          \ a:apiname, s:registry,
          \ 'An API name "%value" has been already registered'
          \)
    call gista#util#validate#not_empty(
          \ a:baseurl,
          \ 'An API baseurl cannot be empty',
          \)
    call gista#util#validate#pattern(
          \ a:baseurl, '^https\?://',
          \ 'An API baseurl "%value" requires to follow "%pattern"'
          \)
    let s:registry[a:apiname] = a:baseurl
  catch /^vim-gista: ValidationError/
    call gista#util#prompt#error(v:exception)
  endtry
endfunction " }}}
function! gista#api#unregister(apiname) abort " {{{
  try
    call gista#util#validate#key_exists(
          \ a:apiname, s:registry,
          \ 'An API name "%value" has not been registered yet',
          \)
    unlet s:registry[a:apiname]
  catch /^vim-gista: ValidationError/
    call gista#util#prompt#error(v:exception)
  endtry
endfunction " }}}

function! gista#api#get_current_client() abort " {{{
  if empty(s:current_client)
    let default_apiname  = s:get_default_apiname()
    let s:current_client = s:get_client(default_apiname)
  endif
  return s:current_client
endfunction " }}}
function! gista#api#get_client(apiname) abort " {{{
  if empty(a:apiname)
    return gista#api#get_current_client()
  else
    call s:validate_apiname(a:apiname)
    return s:get_client(a:apiname)
  endif
endfunction " }}}

function! gista#api#switch(...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'apiname': '',
        \ 'username': 0,
        \ 'permanent': 0,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_client(options.apiname)
  if type(options.username) == type('')
    if empty(options.username)
      call s:logout(client, options)
    else
      call s:login(client, options.username, options)
    endif
  endif
  let s:current_client = client
  return client
endfunction " }}}
function! gista#api#session_enter(...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'apiname': '',
        \ 'username': 0,
        \ 'permanent': 0,
        \}, get(a:000, 0, {}),
        \)
  if exists('s:previous_client')
    call gista#util#prompt#throw(
          \ 'SessionError: gista#api#session_exit() has not been called',
          \)
  endif
  let s:previous_client = deepcopy(
        \ gista#api#get_client(options.apiname)
        \)
  call gista#api#switch(options)
endfunction " }}}
function! gista#api#session_exit() abort " {{{
  if !exists('s:previous_client')
    call gista#util#prompt#throw(
          \ 'SessionError: gista#api#session_enter() has not been called',
          \)
    return
  endif
  let s:current_client = s:previous_client
  unlet s:previous_client
endfunction " }}}

function! gista#api#complete_apiname(arglead, cmdline, cursorpos, ...) abort " {{{
  let apinames = keys(s:registry)
  return filter(apinames, 'v:val =~# "^" . a:arglead')
endfunction " }}}
function! gista#api#complete_username(arglead, cmdline, cursorpos, ...) abort " {{{
  let options = extend({
        \ 'apiname': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let client = gista#api#get_client(options.apiname)
    let usernames = client.token_cache.keys()
    return filter(usernames, 'v:val =~# "^" . a:arglead')
  catch /^vim-gista/
    " fail silently
    return []
  endtry
endfunction " }}}

function! gista#api#throw_api_exception(res) abort " {{{
  call gista#util#prompt#throw(s:G.build_exception_message(a:res))
endfunction " }}}

" Register APIs
call gista#api#register('GitHub', 'https://api.github.com')

" Configure Web.API.GitHub
call s:G.set_config({
      \ 'authorize_scopes': ['gist'],
      \ 'authorize_note': printf('vim-gista@%s:%s', hostname(), localtime()),
      \ 'authorize_note_url': 'https://github.com/lambdalisue/vim-gista',
      \ 'skip_authentication': 1,
      \})

" Configure variables
call gista#define_variables('api', {
      \ 'cache_dir': '~/.cache/vim-gista',
      \ 'default_apiname': 'GitHub',
      \ 'default_username': '',
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
