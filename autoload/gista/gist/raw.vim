"******************************************************************************
" GitHub Raw API module
"
" Plugin developers should use gista#gist#api instead of gista#gist#raw.
" This module is for low level API manipulations
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


" Private functions
function! s:get_api_url(...) abort " {{{
  if !exists('s:gist_api_url')
    let url = g:gista#gist_api_url
    let url = substitute(url, '/$', '', '')
    let s:gist_api_url = url
  endif
  let bit = map(copy(a:000), 'substitute(v:val, "/", "", "g")')
  return join(gista#utils#vital#cons(s:gist_api_url, bit), '/')
endfunction " }}}
function! s:get_tokens() abort " {{{
  if !exists('s:tokens')
    if !exists('s:tokens_directory')
      let value = g:gista#tokens_directory
      let s:tokens_directory = fnamemodify(expand(value), ':p')
    endif
    let s:tokens = gista#utils#cache#new('tokens', s:tokens_directory)
  endif
  return s:tokens
endfunction " }}}
function! s:get_token(username) abort " {{{
  return s:get_tokens().get(a:username)
endfunction " }}}
function! s:set_token(username, token) abort " {{{
  return s:get_tokens().set(a:username, a:token)
endfunction " }}}
function! s:get_auth() abort " {{{
  if !exists('s:auth')
    let s:auth = {}
    let s:auth.username = ''
    let s:auth.token = ''
    lockvar s:auth
  endif
  return [s:auth.username, s:auth.token]
endfunction " }}}
function! s:set_auth(username, token) abort " {{{
  unlockvar! s:auth
  let s:auth = {}
  let s:auth.username = a:username
  let s:auth.token = a:token
  lockvar s:auth
endfunction " }}}
function! s:get_anonymous_header() abort " {{{
  return {}
endfunction " }}}
function! s:get_authenticated_header() abort " {{{
  let [username, token] = s:get_auth()
  return {'Authorization': 'token ' . token}
endfunction " }}}


" Authentication
function! gista#gist#raw#authorize(username, settings) abort " {{{
  " Authorize GitHub API with username and password to get Access Token.
  " Note: it seems like Python client cannot be used for authorization
  let settings = extend({
        \ 'client': ['curl', 'wget'],
        \}, a:settings)
  redraw
  echohl GistaTitle
  echo 'Authorization:'
  echohl None
  echo 'A GitHub password of "' . a:username . '" is required.'
        \ 'The password is used only for obtaining an access token from'
        \ 'GitHub API and never be stored.'
  echohl GistaQuestion
  let password = inputsecret('GitHub password for ' . a:username . ': ')
  echohl None
  if empty(password)
    redraw
    echohl GistaWarning
    echon 'Canceled.'
    echohl None
    return
  endif

  let url = s:get_api_url('authorizations')
  let params = {
        \   'scopes'   : ['gist'],
        \   'note'     : 'vim-gista@' . hostname(),
        \   'note_url' : 'http://github.com/lambdalisue/vim-gista/',
        \}
  let insecure_password = a:username . ':' . password
  let insecure_password = gista#utils#vital#base64_encode(insecure_password)
  let headers = {
        \ 'Authorization' : 'basic ' . insecure_password,
        \}

  redraw | echo 'Requesting an authorization token ...'
  let res = gista#utils#vital#post(url, params, headers, settings)

  " is a tow-factor authentication required?
  let h = filter(res.header, 'stridx(v:val, "X-GitHub-OTP:") == 0')
  if len(h)
    redraw
    echohl GistaTitle
    echo  'Two-factor authentication:'
    echohl None
    echo  'It seems that "' . a:username . '" enabled a two-factor authentication. '
    echon 'Please input a six digits two-factor authentication code.'
    echohl GistaQuestion
    let otp = input('Two-factor authentication code: ')
    echohl None
    if len(otp) == 0
      redraw
      echohl GistaWarning
      echo 'Canceled.'
      echohl None
      return
    endif
    " re-authorize with OTP
    let headers["X-GitHub-OTP"] = otp
    redraw | echo 'Requesting an authorization token with OTP ...'
    let res = gista#utils#vital#post(url, params, headers, settings)
  endif

  if res.status == 201
    return [a:username, res.content.token]
  endif

  redraw
  echohl GistaWarning
  echo  'Authorization has failed:'
  echohl None
  echo  res.status . ' ' . res.statusText . '. '
  if has_key(res.content, 'message')
    echo 'Message: "' . res.content.message . '"'
  endif
  if res.status == 401
    echohl GistaWarning
    echo 'If you already have a personal access token for "vim-gista", remove and try again'
    echohl None
  endif
  return
endfunction " }}}
function! gista#gist#raw#authorize2(token, settings) abort " {{{
  " Authorize with a Personal Access Token
  " Note: it seems like Python client cannot be used for authorization
  let settings = extend({
        \ 'client': ['curl', 'wget'],
        \}, a:settings)

  redraw | echo 'Confirming the personal access token ...'
  let res = gista#utils#vital#get(s:get_api_url('user'), {}, {
        \ 'Authorization': 'token ' . a:token
        \}, settings)
  if res.status == 200
    return [res.content.login, a:token]
  endif

  redraw
  echohl GistaWarning
  echo  'Authorization has faield:'
  echohl None
  echo  res.status . ' ' . res.statusText . '. '
  if has_key(res.content, 'message')
    echo 'Message: "' . res.content.message . '"'
  endif
  return
endfunction " }}}
function! gista#gist#raw#is_authenticated() abort " {{{
  let [username, token] = s:get_auth()
  return !(empty(username) || empty(token))
endfunction " }}}
function! gista#gist#raw#get_authenticated_user() abort " {{{
  let [username, token] = s:get_auth()
  return username
endfunction " }}}
function! gista#gist#raw#login(...) abort " {{{
  let authenticated_user = gista#gist#raw#get_authenticated_user()
  let is_authenticated = gista#gist#raw#is_authenticated()
  let username = get(a:000, 0, authenticated_user)
  let settings = extend({
        \ 'use_default_username': 1,
        \ 'allow_anonymous': 0,
        \}, get(a:000, 1, {}))
  if is_authenticated && username == authenticated_user
    " the user have already logged in
    return s:get_authenticated_header()
  elseif !is_authenticated && empty(username) && settings.use_default_username
    " the user have not authenticated yet so use default username
    let username = g:gista#github_user
  endif

  if empty(username) && settings.allow_anonymous
    return s:get_anonymous_header()
  elseif empty(username)
    redraw
    echohl GistaTitle
    echo  'GitHub Login:'
    echohl None
    echo  'Please input a Personal Access Token (PAT) or GitHub username. '
    echon 'If you input a PAT, the username will be automatically determined. '
    echo  'You can set default username (but not PAT) with "g:gista#github_user".'
    let username = input('Personal Access Token or Username: ')
    if len(username) == 0
      redraw
      echohl GistaWarning
      echo 'Canceled.'
      echohl None
      return []
    endif
  endif

  " If the user have logged in, use cached token
  let token = s:get_token(username)
  if empty(token)
    " the user have not logged in yet, require to logged in
    if len(username) == 40
      " Personal Access Token
      let ret = gista#gist#raw#authorize2(username, settings)
      if !empty(ret)
        " authorize2 will return real login name
        let username = ret[0]
        let token = ret[1]
      endif
    else
      let ret = gista#gist#raw#authorize(username, settings)
      if !empty(ret)
        let token = ret[1]
      endif
    endif

    if !empty(token)
      let token_filename = s:get_tokens().filename
      redraw
      echohl GistaTitle
      echo  'Logged into GitHub:'
      echohl None
      echo  'A login information of "' . username . '" is stored in a "'
      echon token_filename . '". '
      echon 'Run gista#gist#raw#logout() to revoke the login information.'
    else
      " Login failed. Do not show any message because user already know that
      " login was failed (all messages are shown in s:authorize or
      " s:authorize2)
      " Return anonymous header instead
      return s:get_anonymous_header()
    endif
  endif
  " Login success
  call s:set_token(username, token)
  call s:set_auth(username, token)
  return s:get_authenticated_header()
endfunction " }}}
function! gista#gist#raw#logout(...) abort " {{{
  let settings = extend({
        \ 'permanently': 0,
        \}, get(a:000, 0, {}))
  if gista#gist#raw#is_authenticated()
    let save_username = gista#gist#raw#get_authenticated_user()
    call s:set_auth('', '')

    redraw
    let token_filename = s:get_tokens().filename
    if settings.permanently
      call s:get_tokens().remove(save_username)
      echohl GistaTitle
      echo  'Permanently logged out from GitHub:'
      echohl None
      echo  printf('A login information of "%s" is removed from a "%s". ',
            \ save_username,
            \ token_filename
            \)
      echon 'Run gista#gist#raw#login() to login again.'
    else
      echohl GistaTitle
      echo  'Temporary logged out from GitHub:'
      echohl None
      echo  printf('A login information of "%s" have not removed from a "%s". ',
            \ save_username,
            \ token_filename
            \)
      echon 'Run gista#gist#raw#logout({"permanently": 1}) to logged out '
            \ 'permanently or run gista#gist#raw#login() to login again.'
    endif
  endif
endfunction " }}}


" API
function! gista#gist#raw#get(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))

  let authenticated_user = gista#gist#raw#get_authenticated_user()
  let header = gista#gist#raw#login(authenticated_user, {
        \ 'allow_anonymous': 1,
        \})
  let request_settings = gista#utils#vital#omit(settings, [
        \ 'anonymous',
        \])

  redraw | echo 'Requesting a gist (' . a:gistid . ') ...'
  return gista#utils#vital#get(
        \ s:get_api_url('gists', a:gistid),
        \ {},
        \ header,
        \ request_settings)
endfunction " }}}
function! gista#gist#raw#list(lookup, ...) abort " {{{
  let settings = extend({
        \ 'page': -1,
        \ 'since': '',
        \}, get(a:000, 0, {}))

  let authenticated_user = gista#gist#raw#get_authenticated_user()
  let header = gista#gist#raw#login(authenticated_user, {
        \ 'allow_anonymous': 1,
        \})

  let is_authenticated = gista#gist#raw#is_authenticated()
  let username = gista#gist#raw#get_authenticated_user()
  if is_authenticated && (a:lookup == username || a:lookup == '')
    let url = s:get_api_url('gists')
  elseif is_authenticated && a:lookup == 'starred'
    let url = s:get_api_url('gists', 'starred')
  elseif a:lookup == 'public'
    let url = s:get_api_url('gists', a:lookup)
    " public gists should not be loaded recursively
    if settings.page == -1
      let settings.page = 1
    endif
  else
    if empty(a:lookup)
      redraw
      echohl GistaError
      echo 'No lookup username is specified.'
      echohl None
      echo 'You have not logged in your GitHub account thus you have to'
            \ 'specify a GitHub username to lookup.'
      return {}
    endif
    let url = s:get_api_url('users', a:lookup, 'gists')
  endif

  let terminal = -1
  let params = gista#utils#vital#pick(settings, ['page', 'since'])
  let params = filter(params, '!empty(v:val)')
  let params.page = params.page <= 0 ? 1 : params.page

  let request_settings = gista#utils#vital#omit(settings, [
        \ 'page',
        \ 'since',
        \])
  let request_settings['default_content'] = '[]'
  let loaded_gists = []
  let res = {}

  redraw | echo 'Requesting gists ...'
  while terminal == -1 || params.page <= terminal
    let res = gista#utils#vital#get(url, params, header, request_settings)
    if res.status != 200
      break
    elseif terminal == -1 && settings.page == -1
      try
        let links = split(res.header[match(res.header, 'Link')], ',')
        let link = links[match(links, 'rel=[''"]last[''"]')]
        let terminal = str2nr(matchlist(link, '\%(page=\)\(\d\+\)')[1])
      catch
        let terminal = -1
      endtry
    endif

    let ct = copy(res.content)
    " filter fields to reduce cache size
    call map(ct, 'gista#utils#vital#pick(v:val, [
          \ "id","description","public","files",
          \ "created_at", "updated_at",
          \])')
    " filter files to reduce cache size
    call map(ct, 'extend({"files": map(v:val.files, "{}")}, v:val)')
    let loaded_gists = gista#utils#vital#concat([loaded_gists, ct])

    if settings.page != -1 || terminal <= 0
      break
    endif

    let status = 'Requesting gists ... '
    let status = printf(
          \ '%s %d/%d pages has been loaded (Ctrl-C to cancel)',
          \ status, params.page, terminal
          \)
    redraw | echo status
    let params.page += 1
  endwhile

  if res.status == 200
    let res.content = loaded_gists
  endif
  return res
endfunction " }}}
function! gista#gist#raw#list_commits(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#gist#raw#login()
  if empty(header)
    return {}
  endif

  redraw | echo 'Listing commits of gist (' . a:gistid . ') ...'
  let request_settings = gista#utils#vital#omit(settings, [])
  return gista#utils#vital#get(
        \ s:get_api_url('gists', a:gistid, 'commits'),
        \ {}, header,
        \ request_settings)
endfunction " }}}
function! gista#gist#raw#list_forks(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#gist#raw#login()
  if empty(header)
    return {}
  endif

  redraw | echo 'Listing forks of gist (' . a:gistid . ') ...'
  let request_settings = gista#utils#vital#omit(settings, [])
  return gista#utils#vital#get(
        \ s:get_api_url('gists', a:gistid, 'forks'),
        \ {}, header,
        \ request_settings)
endfunction " }}}
function! gista#gist#raw#post(filenames, contents, ...) abort " {{{
  let settings = extend({
        \ 'description': '',
        \ 'public': 1,
        \ 'anonymous': 0,
        \}, get(a:000, 0, {}))
  if settings.anonymous
    let header = s:get_anonymous_header()
  else
    let authenticated_user = gista#gist#raw#get_authenticated_user()
    let header = gista#gist#raw#login(authenticated_user, {
          \ 'allow_anonymous': 1,
          \})
  endif

  let gist = {
        \ 'description': settings.description,
        \ 'public': gista#utils#vital#to_boolean(settings.public),
        \ 'files': {},
        \}
  for [filename, content] in gista#utils#vital#zip(a:filenames, a:contents)
    let gist.files[filename] = {'content': content}
  endfor

  let request_settings = gista#utils#vital#omit(settings, [
        \ 'description',
        \ 'public',
        \ 'anonymous',
        \])
  redraw | echo 'Posting gist ...'
  return gista#utils#vital#post(
        \ s:get_api_url('gists'),
        \ gist, header,
        \ request_settings)
endfunction " }}}
function! gista#gist#raw#patch(gist, filenames, contents, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))

  let header = gista#gist#raw#login()
  if empty(header)
    return {}
  endif

  let partial = {
        \ 'description': a:gist.description,
        \ 'files': {},
        \}
  for [filename, content] in gista#utils#vital#zip(a:filenames, a:contents)
    let partial.files[filename] = {'content': content}
  endfor
  if has_key(settings, 'description') && !empty(settings.description)
    let partial.description = settings.description
  endif

  let request_settings = gista#utils#vital#omit(settings, [
        \ 'description',
        \])

  redraw | echo 'Patching gist (' . a:gist.id . ') ...'
  return gista#utils#vital#patch(
        \ s:get_api_url('gists', a:gist.id),
        \ partial, header,
        \ request_settings)
endfunction " }}}
function! gista#gist#raw#rename(gist, filenames, new_filenames, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#gist#raw#login()
  if empty(header)
    return {}
  endif

  let partial = {
        \ 'description': a:gist.description,
        \ 'files': {},
        \}
  for [filename, new_filename] in gista#utils#vital#zip(
        \ a:filenames, a:new_filenames)
    let partial.files[filename] = {
          \ 'filename': new_filename,
          \ 'content': a:gist.files[filename].content,
          \}
  endfor

  redraw | echo 'Renaming "' . join(a:filenames, ",") . '" ...'
  let request_settings = gista#utils#vital#omit(settings, [])
  return gista#utils#vital#patch(
        \ s:get_api_url('gists', a:gist.id),
        \ partial, header,
        \ request_settings)
endfunction " }}}
function! gista#gist#raw#remove(gist, filenames, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#gist#raw#login()
  if empty(header)
    return {}
  endif

  let partial = {
        \ 'description': a:gist.description,
        \ 'files': {},
        \}
  for filename in a:filenames
    let partial.files[filename] = gista#utils#vital#null()
  endfor


  redraw | echo 'Removing "' . join(a:filenames, ",") . '" from the gist ...'
  let request_settings = gista#utils#vital#omit(settings, [])
  return gista#utils#vital#patch(
        \ s:get_api_url('gists', a:gist.id),
        \ partial, header,
        \ request_settings)
endfunction " }}}
function! gista#gist#raw#delete(gist_or_gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#gist#raw#login()
  if empty(header)
    return {}
  endif

  if type(a:gist_or_gistid) == 1
    let gistid = a:gist_or_gistid
  else
    let gistid = a:gist_or_gistid.id
  endif

  redraw | echo 'Deleting gist (' . gistid . ') ...'
  let request_settings = gista#utils#vital#omit(settings, [])
  return gista#utils#vital#delete(
        \ s:get_api_url('gists', gistid),
        \ header,
        \ request_settings)
endfunction " }}}
function! gista#gist#raw#star(gist_or_gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#gist#raw#login()
  if empty(header)
    return {}
  endif

  if type(a:gist_or_gistid) == 1
    let gistid = a:gist_or_gistid
  else
    let gistid = a:gist_or_gistid.id
  endif

  redraw | echo 'Star gist (' . gistid . ') ...'
  let request_settings = gista#utils#vital#omit(settings, [])
  return gista#utils#vital#put(
        \ s:get_api_url('gists', gistid, 'star'),
        \ {}, header,
        \ request_settings)
endfunction " }}}
function! gista#gist#raw#unstar(gist_or_gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#gist#raw#login()
  if empty(header)
    return {}
  endif

  if type(a:gist_or_gistid) == 1
    let gistid = a:gist_or_gistid
  else
    let gistid = a:gist_or_gistid.id
  endif

  redraw | echo 'Unstar gist (' . gistid . ') ...'
  let request_settings = gista#utils#vital#omit(settings, [])
  return gista#utils#vital#delete(
        \ s:get_api_url('gists', gistid, 'star'),
        \ header,
        \ request_settings)
endfunction " }}}
function! gista#gist#raw#is_starred(gist_or_gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#gist#raw#login()
  if empty(header)
    return {}
  endif

  if type(a:gist_or_gistid) == 1
    let gistid = a:gist_or_gistid
  else
    let gistid = a:gist_or_gistid.id
  endif

  redraw | echo 'Check whether if the gist (' . gistid . ') is starred...'
  let request_settings = gista#utils#vital#omit(settings, [])
  return gista#utils#vital#get(
        \ s:get_api_url('gists', gistid, 'star'),
        \ {}, header,
        \ request_settings)
endfunction " }}}
function! gista#gist#raw#fork(gist_or_gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#gist#raw#login()
  if empty(header)
    return {}
  endif

  if type(a:gist_or_gistid) == 1
    let gistid = a:gist_or_gistid
  else
    let gistid = a:gist_or_gistid.id
  endif

  redraw | echo 'Forking gist (' . gistid . ') ...'
  let request_settings = gista#utils#vital#omit(settings, [])
  return gista#utils#vital#post(
        \ s:get_api_url('gists', gistid, 'forks'),
        \ {}, header,
        \ request_settings)
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
