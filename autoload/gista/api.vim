let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:C = s:V.import('System.Cache')
let s:P = s:V.import('System.Filepath')
let s:D = s:V.import('Data.Dict')
let s:G = s:V.import('Web.API.GitHub')

let s:registry = {}
let s:current_apiname = ''
let s:current_username = ''
let s:current_anonymous = 0

function! s:get_client_cache() abort " {{{
  if !exists('s:client_cache')
    let s:client_cache = s:C.new('memory')
  endif
  return s:client_cache
endfunction " }}} 
function! s:get_token_cache(name) abort " {{{
  if !exists('s:token_cache')
    let s:token_cache = s:C.new('memory')
  endif
  if s:token_cache.has(a:name)
    return s:token_cache.get(a:name)
  endif
  let token_cache = s:C.new('singlefile', {
        \ 'cache_file': expand(s:P.join(g:gista#api#cache_dir, 'token', a:name)),
        \ 'autodump': 1,
        \})
  call s:token_cache.set(a:name, token_cache)
  return token_cache
endfunction " }}} 
function! s:get_entry_cache(name) abort " {{{
  if !exists('s:entry_cache')
    let s:entry_cache = s:C.new('memory')
  endif
  if s:entry_cache.has(a:name)
    return s:entry_cache.get(a:name)
  endif
  let entry_cache = s:C.new('singlefile', {
        \ 'cache_file': expand(s:P.join(g:gista#api#cache_dir, 'entry', a:name)),
        \ 'autodump': 1,
        \})
  call s:entry_cache.set(a:name, entry_cache)
  return entry_cache
endfunction " }}}
function! s:get_content_cache(name) abort " {{{
  if !exists('s:content_cache')
    let s:content_cache = s:C.new('memory')
  endif
  if s:content_cache.has(a:name)
    return s:content_cache.get(a:name)
  endif
  let content_cache = s:C.new('singlefile', {
        \ 'cache_file': expand(s:P.join(g:gista#api#cache_dir, 'content', a:name)),
        \ 'autodump': 1,
        \})
  call s:content_cache.set(a:name, content_cache)
  return content_cache
endfunction " }}}

function! s:ask_apiname(...) abort " {{{
  redraw
  let names = gista#api#registered_apinames()
  if len(names) == 1
    return names[0]
  endif
  let ret = gista#util#prompt#inputlist(
        \ 'Please select an API name:',
        \ names,
        \)
  return ret ? names[ret - 1] : ''
endfunction " }}}
function! s:ask_username(...) abort " {{{
  redraw
  return gista#util#prompt#ask(
        \ 'Please input a username for API: ', '',
        \ 'customlist,gista#complete#username',
        \)
endfunction " }}}
function! s:set_current_apiname(value) abort " {{{
  let s:current_apiname = a:value
endfunction " }}}
function! s:set_current_username(value) abort " {{{
  let s:current_username = a:value
endfunction " }}}
function! s:set_current_anonymous(value) abort " {{{
  let s:current_anonymous = a:value
endfunction " }}}


function! gista#api#register(apiname, baseurl) abort " {{{
  " validation
  call gista#validate#apiname(a:apiname)
  call gista#validate#baseurl(a:baseurl)
  call gista#util#validate#uniq(
        \ s:registry, a:apiname,
        \ 'An API name "%key" has already been registered'
        \)
  let s:registry[a:apiname] = a:baseurl
endfunction " }}}
function! gista#api#unregister(apiname) abort " {{{
  " validation
  call gista#util#validate#no_uniq(
        \ s:registry, a:apiname,
        \ 'An API name "%key" has not been registered yet'
        \)
  unlet s:registry[a:apiname]
endfunction " }}}
function! gista#api#registered_apinames() abort " {{{
  return keys(s:registry)
endfunction " }}}

function! gista#api#get_apiname(apiname) abort " {{{
  let apiname = empty(a:apiname)
        \ ? empty(g:gista#api#default_apiname)
        \   ? s:ask_apiname()
        \   : g:gista#api#default_apiname
        \ : a:apiname
  call gista#validate#apiname(apiname)
  return apiname
endfunction " }}}
function! gista#api#get_username(username) abort " {{{
  let apiname = gista#api#get_current_apiname()
  if !empty(apiname)
    let client = gista#api#client({ 'apiname': apiname })
    let authorized_username = client.get_authorized_username()
  else
    let authorized_username = ''
  endif
  let username = empty(a:username)
        \ ? empty(g:gista#api#default_username)
        \   ? empty(authorized_username)
        \     ? s:ask_username()
        \     : authorized_username
        \   : g:gista#api#default_username
        \ : a:username
  call gista#validate#username(username)
  return username
endfunction " }}}
function! gista#api#get_current_apiname() abort " {{{
  return s:current_apiname
endfunction " }}}
function! gista#api#get_current_username() abort " {{{
  return s:current_username
endfunction " }}}
function! gista#api#get_current_anonymous() abort " {{{
  return s:current_anonymous
endfunction " }}}

function! gista#api#client(...) abort " {{{
  let options = extend({
        \ 'apiname': '',
        \}, get(a:000, 0, {}),
        \)
  let apiname = gista#api#get_apiname(options.apiname)
  let client_cache = s:get_client_cache()
  if client_cache.has(apiname)
    call s:set_current_apiname(apiname)
    return client_cache.get(apiname)
  endif
  let client = s:G.new({
        \ 'baseurl': s:registry[apiname],
        \ 'token_cache': s:get_token_cache(apiname),
        \})
  " extend client
  let client.name = apiname
  let client.entry_cache = s:get_entry_cache(apiname)
  let client.content_cache = s:get_content_cache(apiname)
  call s:set_current_apiname(apiname)
  call client_cache.set(apiname, client)
  return client
endfunction " }}} 
function! gista#api#authorized_client(...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'username': '',
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#client(options)
  let username = gista#api#get_username(options.username)
  try
    call client.login(username, s:D.pick(options, ['verbose']))
  catch /^vital: Web.API.GitHub:/
    throw substitute(v:exception, '^vital: Web.API.GitHub:', 'vim-gista:', '')
  endtry
  call s:set_current_username(username)
  return client
endfunction " }}}

function! gista#api#call_get(...) abort " {{{
  let options = extend({
        \ 'anonymous': g:gista#api#default_anonymous,
        \}, get(a:000, 0, {})
        \)
  call s:set_current_anonymous(options.anonymous)
  let client = options.anonymous
        \ ? gista#api#client(options)
        \ : gista#api#authorized_client(options)
  return call('gista#api#get#call', [client, options])
endfunction " }}}
function! gista#api#call_read(...) abort " {{{
  let options = extend({
        \ 'anonymous': g:gista#api#default_anonymous,
        \}, get(a:000, 0, {})
        \)
  call s:set_current_anonymous(options.anonymous)
  let client = options.anonymous
        \ ? gista#api#client(options)
        \ : gista#api#authorized_client(options)
  return call('gista#api#read#call', [client, options])
endfunction " }}}
function! gista#api#call_list(...) abort " {{{
  let options = extend({
        \ 'anonymous': g:gista#api#default_anonymous,
        \}, get(a:000, 0, {})
        \)
  call s:set_current_anonymous(options.anonymous)
  let client = options.anonymous
        \ ? gista#api#client(options)
        \ : gista#api#authorized_client(options)
  return call('gista#api#list#call', [client, options])
endfunction " }}}
function! gista#api#call_post(...) abort " {{{
  let options = extend({
        \ 'anonymous': g:gista#api#default_anonymous,
        \}, get(a:000, 0, {})
        \)
  call s:set_current_anonymous(options.anonymous)
  let client = options.anonymous
        \ ? gista#api#client(options)
        \ : gista#api#authorized_client(options)
  return call('gista#api#post#call', [client, options])
endfunction " }}}
function! gista#api#call_patch(...) abort " {{{
  let options = extend({
        \ 'anonymous': 0,
        \}, get(a:000, 0, {})
        \)
  if options.anonymous
    call gista#util#prompt#throw(
          \ 'Patching a gist cannot be performed as an anonymous user',
          \)
  endif
  call s:set_current_anonymous(0)
  let client = gista#api#authorized_client(options)
  return call('gista#api#patch#call', [client, options])
endfunction " }}}


" Register APIs
call gista#api#register('GitHub', 'https://api.github.com')

" Configure Web.API.GitHub
call s:G.set_config({
      \ 'authorize_scopes': ['gist'],
      \ 'authorize_note': printf('vim-gista@%s:%s', hostname(), localtime()),
      \ 'authorize_note_url': 'https://github.com/lambdalisue/vim-gista',
      \})

" Configure variables
call gista#define_variables('api', {
      \ 'cache_dir': '~/.cache/vim-gista',
      \ 'default_apiname': '',
      \ 'default_username': '',
      \ 'default_anonymous': 0,
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
