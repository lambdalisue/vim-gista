let s:save_cpo = &cpoptions
set cpoptions&vim

" default config
let s:config = {}
let s:config.baseurl = 'https://api.github.com/'
let s:config.authorize_scopes = []
let s:config.authorize_note = printf('vim@%s:%s', hostname(), localtime())
let s:config.authorize_note_url = ''

function! s:_vital_loaded(V) abort " {{{
  let s:C = a:V.import('System.Cache')
  let s:J = a:V.import('Web.JSON')
  let s:H = a:V.import('Web.HTTP')
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'System.Cache',
        \ 'Web.JSON',
        \ 'Web.HTTP',
        \]
endfunction " }}}
function! s:_throw(msgs) abort " {{{
  let msgs = type(a:msgs) == type([]) ? a:msgs : [a:msgs]
  throw printf('vital: Web.API.GitHub: %s', join(msgs, "\n"))
endfunction " }}}

let s:client = {}
function! s:client.get_api_url(...) abort " {{{
  let base_url = substitute(self.baseurl, '/$', '', '')
  let bits = map(copy(a:000), 'substitute(v:val, "^/\|/$", "", "g")')
  return join(extend([base_url], bits), '/')
endfunction " }}}
function! s:client.get_authorize_scopes() abort " {{{
  " See available scopes at
  " https://developer.github.com/v3/oauth/#scopes
  return self.authorize_scopes
endfunction " }}}
function! s:client.get_authorize_note() abort " {{{
  return self.authorize_note
endfunction " }}}
function! s:client.get_authorize_note_url() abort " {{{
  return self.authorize_note_url
endfunction " }}}

function! s:client.authorize_with_password(username, password, ...) abort " {{{
  let otp = get(a:000, 0, '')
  let url = self.get_api_url('authorizations')
  " Note:
  "   It is not impossible to add 'client_id', 'client_secret', and
  "   'fingerprint' but how do you keep 'client_secret' as secret in
  "   Vim script? Thus omit these parameters.
  let params = {
        \ 'scopes':   self.get_authorize_scopes(),
        \ 'note':     self.get_authorize_note(),
        \ 'note_url': self.get_authorize_note_url(),
        \}
  let headers = empty(otp) ? {} : { 'X-GitHub-OTP': otp }
  return self.post(url, params, headers, {
        \ 'anonymous': 1,
        \ 'username': a:username,
        \ 'password': a:password,
        \ 'authMethod': 'basic',
        \})
endfunction " }}}
function! s:client.authorize(username, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {}),
        \)
  redraw
  echohl Question
  let password = inputsecret(printf(
        \ 'Please input a password for "%s": ', a:username,
        \))
  echohl None
  if empty(password)
    return ''
  endif
  if options.verbose
    redraw
    echo 'Requesting an authorization token ...'
  endif
  let res = self.authorize_with_password(a:username, password)
  " check if OTP is required
  let h = filter(res.header, 'stridx(v:val, "X-GitHub-OTP:") == 0')
  if len(h)
    redraw
    echohl Question
    let otp = input('Please input a six digit two-factor authentication code: ')
    echohl None
    if empty(otp)
      return ''
    endif
    " re-authorize with OTP
    if options.verbose
      redraw
      echo 'Requesting an authorization token with OTP ...'
    endif
    let res = self.authorize_with_password(a:username, password, otp)
  endif
  " translate json content to object
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:J.decode(res.content)
  if res.status != 201
    call s:_throw([
          \ printf(
          \   'Authorization as "%s" in "%s" has failed',
          \   a:username, self.baseurl
          \ ),
          \ printf('%s: %s', res.status, res.statusText),
          \ get(res.content, 'message', ''),
          \])
  endif
  return res.content.token
endfunction " }}}
function! s:client.authenticate(username, token, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {}),
        \)
  if options.verbose
    redraw
    echo printf('Confirming a personal access token for "%s" ...', a:username)
  endif
  let url = self.get_api_url('user')
  let res = self.get(url, {}, {}, { 'anonymous': 0, 'token': a:token })
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:J.decode(res.content)
  if res.status != 200
    call s:_throw([
          \ printf(
          \   'Authentication as "%s" in "%s" with a cached token has failed',
          \   a:username, self.baseurl
          \ ),
          \ printf('%s: %s', res.status, res.statusText),
          \ get(res.content, 'message', ''),
          \])
  endif
endfunction " }}}
function! s:client.get_token(username) abort " {{{
  return self.token_cache.get(a:username)
endfunction " }}}
function! s:client.set_token(username, token) abort " {{{
  if empty(a:token)
    return self.token_cache.remove(a:username)
  else
    return self.token_cache.set(a:username, a:token)
  endif
endfunction " }}}
function! s:client.get_authorized_username() abort " {{{
  return get(self, '_authorized_username', '')
endfunction " }}}
function! s:client.set_authorized_username(username) abort " {{{
  if empty(a:username)
    silent! unlet! self._authorized_username
  else
    let self._authorized_username = a:username
  endif
endfunction " }}}
function! s:client.get_header(...) abort " {{{
  let options = extend({
        \ 'anonymous': 0,
        \ 'token': '',
        \ }, get(a:000, 0, {}),
        \)
  if options.anonymous
    return {}
  endif
  if empty(options.token)
    let username = self.get_authorized_username()
    let token = self.get_token(username)
  else
    let token = options.token
  endif
  return empty(token) ? {} : { 'Authorization': 'token ' . token }
endfunction " }}}

" PUBLIC methods
function! s:client.login(username, ...) abort " {{{
  let options = extend({
        \ 'force': 0,
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  let authorized_username = self.get_authorized_username()
  if !options.force && a:username ==# authorized_username
    return
  endif

  let token = self.get_token(a:username)
  if !empty(token)
    call self.authenticate(a:username, token, options)
    call self.set_authorized_username(a:username)
    return
  endif

  let token = self.authorize(a:username, options)
  if empty(token)
    throw s:_throw('Login canceled by user')
  endif
  call self.set_token(a:username, token)
  call self.set_authorized_username(a:username)
endfunction " }}}
function! s:client.logout(...) abort " {{{
  let options = extend({
        \ 'permanent': 0,
        \}, get(a:000, 0, {}),
        \)
  if options.permanent
    let authorized_username = self.get_authorized_username()
    if !empty(authorized_username)
      call self.set_token(authorized_username, '')
    endif
  endif
  return self.set_authorized_username('')
endfunction " }}}
function! s:client.request(...) abort " {{{
  if a:0 == 3
    let settings = a:3
    let settings.method = get(settings, 'method', a:1)
    let settings.url = get(settings, 'url', a:2)
  elseif a:0 == 2
    if type(a:2) == type({})
      let settings = a:2
      let settings.method = get(settings, 'method', 'GET')
      let settings.url = get(settings, 'url', a:1)
    else
      let settings = {}
      let settings.method = get(settings, 'method', a:1)
      let settings.url = get(settings, 'url', a:2)
    endif
  else
    let settings = a:1
  endif
  let settings.url = settings.url =~# '^https\?://'
        \ ? settings.url
        \ : self.get_api_url(settings.url)
  let settings.headers = extend(
        \ self.get_header(settings),
        \ get(settings, 'headers', {}),
        \)
  return s:H.request(settings)
endfunction " }}}
function! s:client.head(url, ...) abort " {{{
  let params   = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = extend({
        \ 'method': 'HEAD',
        \ 'url': a:url,
        \ 'param': params,
        \ 'headers': headers,
        \}, get(a:000, 2, {}),
        \)
  return self.request(settings)
endfunction " }}}
function! s:client.get(url, ...) abort " {{{
  let params   = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = extend({
        \ 'method': 'GET',
        \ 'url': a:url,
        \ 'param': params,
        \ 'headers': headers,
        \}, get(a:000, 2, {}),
        \)
  return self.request(settings)
endfunction " }}}
function! s:client.post(url, ...) abort " {{{
  let params   = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = extend({
        \ 'method': 'POST',
        \ 'url': a:url,
        \ 'data': s:J.encode(params),
        \ 'headers': headers,
        \}, get(a:000, 2, {}),
        \)
  return self.request(settings)
endfunction " }}}
function! s:client.put(url, ...) abort " {{{
  let params   = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = extend({
        \ 'method': 'PUT',
        \ 'url': a:url,
        \ 'data': s:J.encode(params),
        \ 'headers': headers,
        \}, get(a:000, 2, {}),
        \)
  return self.request(settings)
endfunction " }}}
function! s:client.patch(url, ...) abort " {{{
  let params   = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = extend({
        \ 'method': 'PATCH',
        \ 'url': a:url,
        \ 'data': s:J.encode(params),
        \ 'headers': headers,
        \}, get(a:000, 2, {}),
        \)
  return self.request(settings)
endfunction " }}}
function! s:client.delete(url, ...) abort " {{{
  let params   = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = extend({
        \ 'method': 'DELETE',
        \ 'url': a:url,
        \ 'data': s:J.encode(params),
        \ 'headers': headers,
        \}, get(a:000, 2, {}),
        \)
  return self.request(settings)
endfunction " }}}

function! s:new(...) abort " {{{
  let options = extend({
        \ 'baseurl': s:config.baseurl,
        \ 'authorize_scopes': s:config.authorize_scopes,
        \ 'authorize_note': s:config.authorize_note,
        \ 'authorize_note_url': s:config.authorize_note_url,
        \ 'token_cache': s:C.new('memory'),
        \}, get(a:000, 0, {}),
        \)
  return extend(deepcopy(s:client), options)
endfunction " }}}
function! s:get_config() abort " {{{
  return deepcopy(s:config)
endfunction " }}}
function! s:set_config(config) abort " {{{
  call extend(s:config, a:config)
endfunction " }}}

let &cpoptions = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
