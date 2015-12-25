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

" Private functions
function! s:get_client_cache() abort
  if !exists('s:client_cache')
    let s:client_cache = s:C.new('memory')
  endif
  return s:client_cache
endfunction 
function! s:get_token_cache(apiname) abort
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
endfunction 
function! s:get_index_cache(apiname) abort
  if !exists('s:index_cache')
    let s:index_cache = s:C.new('memory')
  endif
  if s:index_cache.has(a:apiname)
    return s:index_cache.get(a:apiname)
  endif
  let cache_dir = expand(s:P.join(g:gista#api#cache_dir, 'index', a:apiname))
  let index_cache = s:C.new('file', {
        \ 'cache_dir': cache_dir,
        \})
  call s:index_cache.set(a:apiname, index_cache)
  return index_cache
endfunction
function! s:get_gist_cache(apiname) abort
  if !exists('s:gist_cache')
    let s:gist_cache = s:C.new('memory')
  endif
  if s:gist_cache.has(a:apiname)
    return s:gist_cache.get(a:apiname)
  endif
  let cache_dir = expand(s:P.join(g:gista#api#cache_dir, 'gist', a:apiname))
  let gist_cache = s:C.new('file', {
        \ 'cache_dir': cache_dir,
        \})
  call s:gist_cache.set(a:apiname, gist_cache)
  return gist_cache
endfunction

function! s:validate_apiname(apiname) abort
  call gista#util#validate#not_empty(
        \ a:apiname,
        \ 'An API name cannot be empty',
        \)
  call gista#util#validate#exists(
        \ a:apiname, keys(s:registry),
        \ 'An API name "%value" has not been registered yet',
        \)
endfunction
function! s:validate_username(username) abort
  call gista#util#validate#pattern(
        \ a:username, '^[a-zA-Z0-9_\-]\+$',
        \ 'An API username "%value" requires to follow "%pattern"'
        \)
endfunction
function! s:get_default_apiname() abort
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
endfunction
function! s:get_default_username(apiname) abort
  if type(g:gista#api#default_username) == type('')
    let username = g:gista#api#default_username
  else
    let default = get(g:gista#api#default_username, '_', '')
    let username = get(g:gista#api#default_username, a:apiname, default)
  endif
  try
    call s:validate_username(username)
    return username
  catch /^vim-gista: ValidationError/
    call gista#util#prompt#warn(v:exception)
    call gista#util#prompt#warn('An anonymous user is used instead')
    return ''
  endtry
endfunction

function! s:login(client, username, options) abort
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
endfunction
function! s:logout(client, options) abort
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
endfunction
function! s:new_client(apiname) abort
  let client = s:G.new({
        \ 'baseurl': s:registry[a:apiname],
        \ 'token_cache': s:get_token_cache(a:apiname),
        \})
  " extend client
  let client.apiname = a:apiname
  let client.index_cache = s:get_index_cache(a:apiname)
  let client.gist_cache = s:get_gist_cache(a:apiname)
  " login if default_username of apiname exists
  let default_username = s:get_default_username(a:apiname)
  if !empty(default_username)
    call s:login(client, default_username, { 'verbose': 1 })
  endif
  return client
endfunction
function! s:get_client(apiname) abort
  let client_cache = s:get_client_cache()
  if client_cache.has(a:apiname)
    return client_cache.get(a:apiname)
  endif
  let client = s:new_client(a:apiname)
  call client_cache.set(a:apiname, client)
  return client
endfunction

" Protected function
function! gista#api#_get_available_apinames() abort
  return keys(s:registry)
endfunction
function! gista#api#_get_available_usernames(apiname) abort
  call s:validate_apiname(a:apiname)
  let client = s:get_client(a:apiname)
  return client.token_cache.keys()
endfunction

" Public function
function! gista#api#register(apiname, baseurl) abort
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
endfunction
function! gista#api#unregister(apiname) abort
  try
    call gista#util#validate#key_exists(
          \ a:apiname, s:registry,
          \ 'An API name "%value" has not been registered yet',
          \)
    unlet s:registry[a:apiname]
  catch /^vim-gista: ValidationError/
    call gista#util#prompt#error(v:exception)
  endtry
endfunction

function! gista#api#get_current_client() abort
  if empty(s:current_client)
    let default_apiname  = s:get_default_apiname()
    let s:current_client = s:get_client(default_apiname)
  endif
  return s:current_client
endfunction
function! gista#api#get_current_apiname() abort
  return gista#api#get_current_client().apiname
endfunction
function! gista#api#get_current_username() abort
  return gista#api#get_current_client().get_authorized_username()
endfunction

function! gista#api#switch_client(apiname, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'username': 0,
        \ 'permanent': 0,
        \}, get(a:000, 0, {})
        \)
  call s:validate_apiname(a:apiname)
  let client = s:get_client(a:apiname)
  if type(options.username) == type('')
    if empty(options.username)
      call s:logout(client, options)
    else
      call s:login(client, options.username, options)
    endif
  endif
  let s:current_client = client
  return client
endfunction

let s:session = {}
function! s:session.enter() abort
  if has_key(self, '_previous_client')
    call gista#util#prompt#throw(
          \ 'SessionError: session.exit() has not been called yet',
          \)
    return
  endif
  let self._previous_client = gista#api#get_current_client()
  call gista#api#switch_client(self.apiname, {
        \ 'verbose': self.verbose,
        \ 'username': self.username,
        \ 'permanent': 0,
        \})
endfunction
function! s:session.exit() abort
  if !has_key(self, '_previous_client')
    call gista#util#prompt#throw(
          \ 'SessionError: session.enter() has not been called yet',
          \)
    return
  endif
  let s:current_client = self._previous_client
  unlet self._previous_client
endfunction
function! gista#api#session(...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'apiname': '',
        \ 'username': 0,
        \}, get(a:000, 0, {}),
        \)
  let apiname = empty(options.apiname)
        \ ? s:get_default_apiname()
        \ : options.apiname
  let session = extend(copy(s:session), {
        \ 'verbose': options.verbose,
        \ 'apiname': apiname,
        \ 'username': options.username,
        \})
  return session
endfunction

function! gista#api#throw_api_exception(response) abort
  call gista#util#prompt#throw(s:G.build_exception_message(a:response))
endfunction

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
