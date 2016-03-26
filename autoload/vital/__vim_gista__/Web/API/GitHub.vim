let s:root = expand('<sfile>:p:h')


function! s:_vital_loaded(V) abort
  let s:Cache = a:V.import('System.Cache')
  let s:JSON = a:V.import('Web.JSON')
  let s:HTTP = a:V.import('Web.HTTP')
  let s:DateTime = a:V.import('DateTime')
  let s:Path = a:V.import('System.Filepath')
  let s:Python = a:V.import('Vim.Python')
  let s:Base64 = a:V.import('Data.Base64')
endfunction
function! s:_vital_depends() abort
  return {
        \ 'modules': [
        \   'System.Cache', 'Web.JSON', 'Web.HTTP',
        \   'DateTime', 'System.Filepath', 'Vim.Python', 'Data.Base64',
        \ ],
        \ 'files': ['./github.py'],
        \}
endfunction
function! s:_vital_created(module) abort
  if !exists('s:config')
    " default config
    let s:config = {}
    let s:config.baseurl = 'https://api.github.com/'
    let s:config.authorize_scopes = []
    let s:config.authorize_note = printf('vim@%s', hostname())
    let s:config.authorize_note_url = ''
    let s:config.skip_authentication = 0
    let s:config.retrieve_python =
          \ (v:version >= 704 || (v:version == 703 && has('patch601')))
          \ && has('python') || has('python3')
    let s:config.retrieve_python_nprocess = 50
    let s:config.retrieve_per_page = 100
    let s:config.retrieve_indicator =
          \ 'Requesting entries from %(url)s [%%(page)d/%(page_count)d]'
  endif
endfunction

function! s:_throw(msgs) abort
  let msgs = type(a:msgs) == type([]) ? a:msgs : [a:msgs]
  throw printf('vital: Web.API.GitHub: %s', join(msgs, "\n"))
endfunction
function! s:_get_header(token) abort
  return empty(a:token) ? {} : { 'Authorization': 'token ' . a:token }
endfunction
function! s:_get_basic_header(username, password, ...) abort
  let otp = get(a:000, 0, '')
  let headers = empty(otp) ? {} : { 'X-GitHub-OTP': otp }
  " Note:
  " Vital.Wet.HTTP's username/password have some bug in python/wget client
  " thus use raw way to specity BASIC auth.
  let insecure_password = a:username . ':' . a:password
  let insecure_password = s:Base64.encode(insecure_password)
  let headers['Authorization'] = 'basic ' . insecure_password
  return headers
endfunction

function! s:_list_authorizations(client, username, password, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'otp': '',
        \}, get(a:000, 0, {}),
        \)
  let url = a:client.get_absolute_url('authorizations')
  let headers = s:_get_basic_header(a:username, a:password, options.otp)
  let settings ={
        \ 'method': 'GET',
        \ 'url': url,
        \ 'headers': headers,
        \}
  if options.verbose
    redraw
    if options.otp
      echo 'Requesting authorizations with OTP...'
    else
      echo 'Requesting authorizations ...'
    endif
  endif
  let res = a:client.request(settings)
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:JSON.decode(res.content)
  return res
endfunction
function! s:_delete_authorization(id, client, username, password, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'otp': '',
        \}, get(a:000, 0, {}),
        \)
  let url = a:client.get_absolute_url('authorizations')
  let headers = s:_get_basic_header(a:username, a:password, options.otp)
  let settings ={
        \ 'method': 'DELETE',
        \ 'url': url . '/' . a:id,
        \ 'headers': headers,
        \}
  if options.verbose
    redraw
    if options.otp
      echo 'Deleting an authorization with OTP...'
    else
      echo 'Deleting an authorization ...'
    endif
  endif
  let res = a:client.request(settings)
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:JSON.decode(res.content)
  return res
endfunction
function! s:_create_authorization(params, client, username, password, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'otp': '',
        \}, get(a:000, 0, {}),
        \)
  let url = a:client.get_absolute_url('authorizations')
  let headers = s:_get_basic_header(a:username, a:password, options.otp)
  let settings ={
        \ 'method': 'POST',
        \ 'url': url,
        \ 'data': s:JSON.encode(a:params),
        \ 'headers': headers,
        \}
  if options.verbose
    redraw
    if options.otp
      echo 'Creating an authorization with OTP...'
    else
      echo 'Creating an authorization ...'
    endif
  endif
  let res = a:client.request(settings)
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:JSON.decode(res.content)
  return res
endfunction

function! s:_authorize(client, username, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {}),
        \)
  redraw
  echohl Question
  let password = inputsecret(printf(
        \ 'Please input a password of "%s" in "%s": ',
        \ a:username, a:client.baseurl,
        \))
  echohl None
  if empty(password)
    return ''
  endif
  let res = s:_list_authorizations(a:client, a:username, password, {
        \ 'verbose': options.verbose,
        \})
  " check if OTP is required
  if len(filter(res.header, 'stridx(v:val, "X-GitHub-OTP:") == 0'))
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
    let res = s:_list_authorizations(a:client, a:username, password, {
          \ 'verbose': options.verbose,
          \ 'otp': otp,
          \})
  else
    let otp = ''
  endif
  if res.status != 200
    call s:_throw([
          \ printf(
          \   'Authorization as "%s" in "%s" has failed',
          \   a:username, a:client.baseurl
          \ ),
          \ printf('%s: %s', res.status, res.statusText),
          \ get(res.content, 'message', ''),
          \])
  endif
  let note = a:client.get_authorize_note()
  let authorizations = res.content
  let authorization = get(filter(
        \ copy(authorizations),
        \ '!empty(v:val.note) && v:val.note ==# note'
        \), 0, {})
  while !empty(authorization)
    redraw
    echohl WarningMsg
    echo printf('A personal access token for "%s" exists', note)
    echohl None
    let intans = inputlist([
          \ 'Would you like to:',
          \ '1. Overwrite existing access token',
          \ '2. Give a new access token name',
          \])
    if intans == 1
      let res = s:_delete_authorization(
            \ authorization.id, a:client, a:username, password, {
            \   'verbose': options.verbose,
            \   'otp': otp,
            \})
      if res.status != 204
        call s:_throw([
              \ printf(
              \   'Authorization as "%s" in "%s" has failed',
              \   a:username, a:client.baseurl
              \ ),
              \ printf('%s: %s', res.status, res.statusText),
              \ get(res.content, 'message', ''),
              \])
      endif
      break
    elseif intans == 2
      let note = input(printf('%s -> ', note), note)
      if empty(note)
        return ''
      endif
      let authorization = get(filter(
            \ copy(authorizations),
            \ '!empty(v:val.note) && v:val.note ==# note'
            \), 0, {})
    else
      return ''
    endif
  endwhile
  let params = {
        \ 'scopes':   a:client.get_authorize_scopes(),
        \ 'note':     note,
        \ 'note_url': a:client.get_authorize_note_url(),
        \}
  let res = s:_create_authorization(
        \ params, a:client, a:username, password, {
        \   'verbose': options.verbose,
        \   'otp': otp,
        \})
  if res.status != 201
    call s:_throw([
          \ printf(
          \   'Authorization as "%s" in "%s" has failed',
          \   a:username, a:client.baseurl
          \ ),
          \ printf('%s: %s', res.status, res.statusText),
          \ get(res.content, 'message', ''),
          \])
  endif
  return res.content.token
endfunction
function! s:_authenticate(client, username, token, ...) abort
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {}),
        \)
  if options.verbose
    redraw
    echo printf(
          \ 'Confirming an access token of "%s" in "%s" ...',
          \ a:username, a:client.baseurl,
          \)
  endif
  let url = a:client.get_absolute_url('user')
  let res = a:client.get(url, {}, s:_get_header(a:token))
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:JSON.decode(res.content)
  if res.status != 200
    call s:_throw([
          \ printf(
          \   'Authentication as "%s" in "%s" with a cached token has failed',
          \   a:username, a:client.baseurl
          \ ),
          \ printf('%s: %s', res.status, res.statusText),
          \ get(res.content, 'message', ''),
          \])
  endif
endfunction

function! s:_build_error_message(errors) abort
  let error_message = []
  for error in a:errors
    let code = get(error, 'code', '')
    if code ==# 'missing'
      call add(error_message, printf(
            \ 'A resource "%s" is missing',
            \ get(error, 'resource', '?'),
            \))
    elseif code ==# 'missing_field'
      call add(error_message, printf(
            \ 'A required field "%s" on a resource "%s" is missing',
            \ get(error, 'field', '?'),
            \ get(error, 'resource', '?'),
            \))
    elseif code ==# 'invalid'
      call add(error_message, printf(
            \ 'The formatting of a field "%s" on a resource "%s" is invalid',
            \ get(error, 'field', '?'),
            \ get(error, 'resource', '?'),
            \))
    elseif code ==# 'already_exists'
      call add(error_message, printf(
            \ 'The value of a field "%s" on a resource "%s" already exists',
            \ get(error, 'field', '?'),
            \ get(error, 'resource', '?'),
            \))
    else
      " Unknown error type
      call add(error_message, string(code))
    endif
  endfor
  return join(error_message, "\n")
endfunction
function! s:_build_rate_limit_message(rate_limit, ...) abort
  if get(a:rate_limit, 'remaining', 1)
    return ''
  endif
  let now_dt   = get(a:000, 0, {})
  let reset_dt = s:DateTime.from_unix_time(a:rate_limit.reset)
  let duration = reset_dt.delta(empty(now_dt) ? s:DateTime.now() : now_dt)
  return printf(
        \ 'Try again %s, or login to use authenticated request',
        \ duration.about(),
        \)
endfunction

function! s:_retrieve_vim_partial(client, settings, indicator, page) abort
  if a:settings.verbose
    redraw | echo substitute(a:indicator, '%(page)d', a:page, 'g')
  endif
  let res = a:client.get(
        \ a:settings.url,
        \ extend(copy(a:settings.param), {
        \  'page': a:page,
        \ })
        \)
  if res.status != 200
    call s:_throw(s:build_exception_message(res))
  endif
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? [] : s:JSON.decode(res.content)
  return res.content
endfunction
function! s:_retrieve_vim(client, settings) abort
  let page_start = a:settings.page_start
  if a:settings.page_end
    let page_end = a:settings.page_end
  else
    if a:settings.verbose
      redraw
      echo 'Requesting the total number of pages ...'
    endif
    let response = a:client.head(
          \ a:settings.url,
          \ a:settings.param
          \)
    let page_count_str = matchstr(
          \ get(s:parse_response_link(response), 'last', ''),
          \ '.*[&?]page=\zs\d\+\ze'
          \)
    let page_end = empty(page_count_str) ? 1 : str2nr(page_count_str)
  endif
  " retrieve pages
  let ir = a:settings.indicator
  let ir = substitute(ir, '%(url)s', a:settings.url, 'g')
  let ir = substitute(ir, '%(page_count)d', page_end - page_start + 1, 'g')
  let ir = substitute(ir, '%%', '%', 'g')
  let entries = []
  call map(
        \ range(page_start, page_end), join([
        \   'extend(entries,',
        \   '  s:_retrieve_vim_partial(a:client, a:settings, ir, v:val)',
        \   ')',
        \ ])
        \)
  return entries
endfunction
" @vimlint(EVL102, 1, l:kwargs)
function! s:_retrieve_python(client, settings) abort
  let python = a:settings.python == 1 ? 0 : a:settings.python
  let kwargs = extend(copy(a:settings.param), {
        \ 'verbose': a:settings.verbose,
        \ 'url': a:client.get_absolute_url(a:settings.url),
        \ 'token': a:client.get_token(),
        \ 'indicator': a:settings.indicator,
        \ 'nprocess': a:settings.python_nprocess,
        \ 'page_start': a:settings.page_start,
        \ 'page_end': a:settings.page_end,
        \})
  execute s:Python.exec_file(s:Path.join(s:root, 'github.py'), python)
  " NOTE:
  " To support neovim, bindeval cannot be used for now.
  " That's why eval_expr is required to call separatly
  let prefix = '_vim_vital_web_api_github'
  let response = s:Python.eval_expr(prefix . '_response', python)
  let code = [
        \ printf('del %s_main', prefix),
        \ printf('del %s_response', prefix),
        \]
  execute s:Python.exec_code(code, python)
  if has_key(response, 'exception')
    call s:_throw(response.exception)
  endif
  return response.entries
endfunction
" @vimlint(EVL102, 0, l:kwargs)

" Public functions
function! s:new(...) abort
  let options = extend(deepcopy(s:config), get(a:000, 0, {}))
  let options = extend({
        \ 'token_cache': s:Cache.new('memory'),
        \}, options,
        \)
  return extend(deepcopy(s:client), options)
endfunction
function! s:get_config() abort
  return deepcopy(s:config)
endfunction
function! s:set_config(config) abort
  call extend(s:config, a:config)
endfunction

function! s:parse_response(response) abort
  return {
        \ 'etag': s:parse_response_etag(a:response),
        \ 'link': s:parse_response_link(a:response),
        \ 'last_modified': s:parse_response_last_modified(a:response),
        \ 'rate_limit': s:parse_response_rate_limit(a:response),
        \}
endfunction
function! s:parse_response_etag(response) abort
  return matchstr(
        \ matchstr(a:response.header, '^ETag:'),
        \ '^ETag: \zs.*$',
        \)
endfunction
function! s:parse_response_link(response) abort
  " https://developer.github.com/guides/traversing-with-pagination/#navigating-through-the-pages
  let bits = split(matchstr(a:response.header, '^Link:'), ',')
  let links = {}
  for bit in bits
    let m = matchlist(bit, '<\(.*\)>; rel="\(.*\)"')
    if empty(m)
      continue
    endif
    let links[m[2]] = m[1]
  endfor
  return links
endfunction
function! s:parse_response_rate_limit(response) abort
  let limit = matchstr(
        \ matchstr(a:response.header, '^X-RateLimit-Limit:'),
        \ '^X-RateLimit-Limit: \zs\d\+$'
        \)
  let remaining = matchstr(
        \ matchstr(a:response.header, '^X-RateLimit-Remaining:'),
        \ '^X-RateLimit-Remaining: \zs\d\+$'
        \)
  let reset = matchstr(
        \ matchstr(a:response.header, '^X-RateLimit-Reset:'),
        \ '^X-RateLimit-Reset: \zs\d\+$'
        \)
  if empty(limit) && empty(remaining) && empty(reset)
    return {}
  endif
  return {
        \ 'limit': empty(limit) ? 0 : str2nr(limit),
        \ 'remaining': empty(remaining) ? 0 : str2nr(remaining),
        \ 'reset': empty(reset) ? 0 : str2nr(reset),
        \}
endfunction
function! s:parse_response_last_modified(response) abort
  return matchstr(
        \ matchstr(a:response.header, '^Last-Modified:'),
        \ '^Last-Modified: \zs.*$'
        \)
endfunction

function! s:build_exception_message(response, ...) abort
  let a:response.content = get(a:response, 'content', {})
  let content = type(a:response.content) == type('')
        \ ? empty(a:response.content) ? {} : s:JSON.decode(a:response.content)
        \ : a:response.content
  let message = get(content, 'message', '')
  let error_message = s:_build_error_message(get(content, 'errors', []))
  let rate_limit_message = s:_build_rate_limit_message(
        \ s:parse_response_rate_limit(a:response),
        \ get(a:000, 0, {})
        \)
  let documentation_url = get(content, 'documentation_url', '')
  let messages = [
        \ empty(message)
        \   ? printf('%s: %s', a:response.status, a:response.statusText)
        \   : printf('%s: %s: %s', a:response.status, a:response.statusText, message),
        \ error_message,
        \ rate_limit_message,
        \ empty(documentation_url)
        \   ? ''
        \   : printf('%s might help you resolve the error', documentation_url)
        \]
  return join(filter(messages, '!empty(v:val)'), "\n")
endfunction

" Instance
let s:client = {}
function! s:client._set_token(username, token) abort
  if empty(a:token)
    return self.token_cache.remove(a:username)
  else
    return self.token_cache.set(a:username, a:token)
  endif
endfunction
function! s:client._set_authorized_username(username) abort
  let self._authorized_username = a:username
endfunction

function! s:client.get_authorize_scopes() abort
  " See available scopes at
  " https://developer.github.com/v3/oauth/#scopes
  return self.authorize_scopes
endfunction
function! s:client.get_authorize_note() abort
  return self.authorize_note
endfunction
function! s:client.get_authorize_note_url() abort
  return self.authorize_note_url
endfunction
function! s:client.get_absolute_url(relative_url) abort
  let baseurl = substitute(self.baseurl, '/$', '', '')
  let partial = substitute(a:relative_url, '^/', '', '')
  return baseurl . '/' . partial
endfunction

function! s:client.is_authorized() abort
  return !empty(self.get_authorized_username())
endfunction
function! s:client.get_token(...) abort
  let username = get(a:000, 0, '')
  let username = empty(username) ? self.get_authorized_username() : username
  return empty(username) ? '' : self.token_cache.get(username)
endfunction
function! s:client.get_header(...) abort
  let username = get(a:000, 0, '')
  let token = self.get_token(username)
  return s:_get_header(token)
endfunction
function! s:client.get_authorized_username() abort
  return get(self, '_authorized_username', '')
endfunction
function! s:client.login(username, ...) abort
  let options = extend({
        \ 'force': 0,
        \ 'verbose': 1,
        \ 'skip_authentication': self.skip_authentication,
        \}, get(a:000, 0, {})
        \)
  let authorized_username = self.get_authorized_username()
  if !options.force && a:username ==# authorized_username
    return
  endif

  let token = self.get_token(a:username)
  if !empty(token)
    if !options.skip_authentication
      call s:_authenticate(self, a:username, token, options)
    endif
    call self._set_authorized_username(a:username)
    return
  endif

  let token = s:_authorize(self, a:username, options)
  if empty(token)
    throw s:_throw('Login canceled by user')
  endif
  call self._set_token(a:username, token)
  call self._set_authorized_username(a:username)
endfunction
function! s:client.logout(...) abort
  let options = extend({
        \ 'permanent': 0,
        \}, get(a:000, 0, {}),
        \)
  if options.permanent
    let authorized_username = self.get_authorized_username()
    if !empty(authorized_username)
      call self._set_token(authorized_username, '')
    endif
  endif
  return self._set_authorized_username('')
endfunction

function! s:client.request(...) abort
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
        \ : self.get_absolute_url(settings.url)
  let settings.headers = extend(
        \ s:_get_header(self.get_token()),
        \ get(settings, 'headers', {}),
        \)
  " Most of API request is json
  let settings.headers = extend({
        \ 'Content-Type': 'application/json',
        \}, settings.headers
        \)
  " neovim currently does not support 'bindeval'
  if has('nvim')
    let settings.client = ['curl', 'wget']
  endif
  return s:HTTP.request(settings)
endfunction
function! s:client.head(url, ...) abort
  let params   = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = {
        \ 'method': 'HEAD',
        \ 'url': a:url,
        \ 'param': params,
        \ 'headers': headers,
        \}
  return self.request(settings)
endfunction
function! s:client.get(url, ...) abort
  let params   = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = {
        \ 'method': 'GET',
        \ 'url': a:url,
        \ 'param': params,
        \ 'headers': headers,
        \}
  return self.request(settings)
endfunction
function! s:client.post(url, ...) abort
  let data     = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = {
        \ 'method': 'POST',
        \ 'url': a:url,
        \ 'data': s:JSON.encode(data),
        \ 'headers': headers,
        \}
  return self.request(settings)
endfunction
function! s:client.put(url, ...) abort
  let data     = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = {
        \ 'method': 'PUT',
        \ 'url': a:url,
        \ 'data': s:JSON.encode(data),
        \ 'headers': headers,
        \}
  return self.request(settings)
endfunction
function! s:client.patch(url, ...) abort
  let data     = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = {
        \ 'method': 'PATCH',
        \ 'url': a:url,
        \ 'data': s:JSON.encode(data),
        \ 'headers': headers,
        \}
  return self.request(settings)
endfunction
function! s:client.delete(url, ...) abort
  let params   = get(a:000, 0, {})
  let headers  = get(a:000, 1, {})
  let settings = {
        \ 'method': 'DELETE',
        \ 'url': a:url,
        \ 'param': params,
        \ 'headers': headers,
        \}
  return self.request(settings)
endfunction

function! s:client.retrieve(...) abort
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
  " fill required default settings
  let settings = extend({
        \ 'verbose': 1,
        \ 'page_start': 1,
        \ 'page_end': 0,
        \ 'indicator': self.retrieve_indicator,
        \ 'python': self.retrieve_python,
        \ 'python_nprocess': self.retrieve_python_nprocess,
        \}, settings
        \)
  " fill required default param
  let settings.param = extend({
        \ 'per_page': self.retrieve_per_page,
        \}, copy(get(settings, 'param', {}))
        \)
  return settings.python
        \ ? s:_retrieve_python(self, settings)
        \ : s:_retrieve_vim(self, settings)
endfunction
