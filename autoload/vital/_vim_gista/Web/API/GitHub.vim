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
  let s:B = a:V.import('Data.Base64')
  let s:J = a:V.import('Web.JSON')
  let s:H = a:V.import('Web.HTTP')
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'System.Cache',
        \ 'Data.Base64',
        \ 'Web.JSON',
        \ 'Web.HTTP',
        \]
endfunction " }}}

let s:client = {}
function! s:client.get_api_url(...) abort " {{{
  let path = substitute(get(a:000, 0, ''), '^/\|/$', '', 'g')
  let base = substitute(self.baseurl, '/$', '', '')
  return join(filter([base, path], 'v:val'), '/')
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
  let insecure_password = s:B.encode(a:username . ':' . a:password)
  let headers = {
        \ 'Authorization' : 'basic ' . insecure_password,
        \ }
  if !empty(otp)
    let headers["X-GitHub-OTP"] = otp
  endif
  return self.post(url, params, headers, { 'anonymous': 1 })
endfunction " }}}
function! s:client.authorize(username, ...) abort " {{{
  " Note:
  "   authorize use BASIC authentication and it won't work with 'python'
  "   thus force to specify 'curl' and 'wget'
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {}),
        \})
  let options.clients = ['curl', 'wget']
  redraw
  if options.verbose > 1
    echohl Title
    echo 'Authorization':
    echohl None
    echo printf('A GitHub password for "%s" is required.', a:username)
    echo 'The password is used only for creating an access toekn from'
          \ 'GitHub API and never be stored.'
  endif
  echohl Question
  let password = inputsecret(printf('GitHub password for "%s": ', a:username))
  echohl None
  if empty(password)
    if options.verbose > 1
      redraw
      echohl WarningMsg
      echo 'Canceled.'
      echohl None
    endif
    return ''
  endif
  if options.verbose > 1
    redraw
    echo 'Requesting an authorization token ...'
  endif
  let res = self.authorize_with_password(a:username, password)
  " check if OTP is required
  let h = filter(res.header, 'stridx(v:val, "X-GitHub-OTP:") == 0')
  if len()
    redraw
    if options.verbose > 1
      echohl Title
      echo 'Two-factor authentication:'
      echohl None
      echo printf('It seems that "%s" enabled a two-factor authentication.')
      echo 'Please input a six digits two-factor authentication code.'
    endif
    echohl Question
    let otp = input('Two-factor authentication code: ')
    echohl None
    if empty(otp)
      if options.verbose > 1
        redraw
        echohl WarningMsg
        echo 'Canceled.'
        echohl None
      endif
      return ''
    endif
    " re-authorize with OTP
    if options.verbose > 1
      redraw
      echo 'Requesting an authorization token with OTP ...'
    endif
    let res = self.authorize_with_password(a:username, password, otp)
  endif
  let res.content = get(res, 'content', '{}')
  let res.content = s:J.decode(res.content || '{}')

  if res.status == 201
    return res.content.token
  endif

  if options.verbose > 0
    redraw
    echohl ErrorMsg
    echo 'Authorization has failed:'
    echohl None
    echo printf('%s %s.', res.status, res.statusText)
    if has_key(res.content, 'message')
      echo printf('Message: "%s"', res.content.message)
    endif
    echo printf(
          \ 'Remove if you already have a personal access token for "%s',
          \ self.get_authorize_note(),
          \)
  endif
  return ''
endfunction " }}}
function! s:client.authenticate(username, token, ...) abort " {{{
  " Note:
  "   authorize use BASIC authentication and it won't work with 'python'
  "   thus force to specify 'curl' and 'wget'
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {}),
        \)
  let options.clients = ['curl', 'wget']
  if options.verbose > 1
    redraw
    echo printf('Confirming the personal access token for "%s" ...', a:username)
  endif
  let url = self.get_api_url('user')
  let headers = {
        \ 'Authorization': 'token ' . a:token,
        \}
  let res = self.get(url, {}, headers, { 'anonymous': 1 })
  if res.status == 200
    return 1
  endif

  if options.verbose > 0
    redraw
    echohl ErrorMsg
    echo 'Authentication has failed:'
    echohl None
    echo printf('%s %s.', res.status, res.statusText)
    if has_key(res.content, 'message')
      echo printf('Message: "%s"', res.content.message)
    endif
  endif
  return 0
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
        \  'anonymous': 0,
        \ }, get(a:000, 0, {}),
        \)
  if options.anonymous
    return {}
  endif
  let username = self.get_authorized_username()
  let token    = self.get_token(username)
  return empty(token) ? {} : { 'Authorization': 'token ' . token }
endfunction " }}}

" PUBLIC methods
function! s:client.login(username, ...) abort " {{{
  let options = extend({
        \ 'force': 0,
        \}, get(a:000, 0, {}),
        \)
  let authorized_username = self.get_authorized_username()
  let username = empty(a:username) ? authorized_username : a:username
  if !options.force
        \ && !empty(authorized_username)
        \ && username ==# authorized_username
    return 1
  endif

  " not authorized yet but no username is specified
  if empty(username)
    return 0
  endif

  let token = self.get_token(username)
  if !empty(token)
    if self.authenticate(username, token, options)
      call self.set_authorized_username(username)
      return 1
    else
      call self.set_authorized_username('')
      return 0
    endif
  endif

  let token = self.authorize(username, options)
  if empty(token)
    call self.set_authorized_username('')
    return 0
  endif
  call self.set_token(username, token)
  call self.set_authorized_username(username)
  return 1
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
function! s:client._request(...) abort " {{{
  return call(s:H.request, a:000, s:H)
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
  let settings.headers = extend(
        \ self.get_header(settings),
        \ get(settings, 'headers', {}),
        \)
  " complete a relative url
  if settings.url !~# '^https?://'
    let settings.url = self.get_api_url(settings.url)
  endif
  let res = self._request(settings)
  return res
endfunction " }}}
function! s:client.get(url, ...) abort " {{{
  let params   = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = extend({
        \ 'method': 'GET',
        \ 'url': a:url,
        \ 'data': s:J.encode(params),
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
        \ 'baseurl': s:config.api_url,
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
