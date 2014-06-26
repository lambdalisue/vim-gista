"******************************************************************************
" GitHub Raw API module
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
  return join(gista#vital#cons(s:gist_api_url, bit), '/')
endfunction " }}}
function! s:get_tokens() abort " {{{
  if !exists('s:tokens')
    if !exists('s:tokens_directory')
      let value = g:gista#tokens_directory
      let s:tokens_directory = fnamemodify(expand(value), ':p')
    endif
    let s:tokens = gista#modules#cache#new('tokens', s:tokens_directory)
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
function! s:is_authenticated() abort " {{{
  let [username, token] = s:get_auth()
  return !(empty(username) || empty(token))
endfunction " }}}
function! s:get_anonymous_header() abort " {{{
  return {}
endfunction " }}}
function! s:get_authenticated_header() abort " {{{
  let [username, token] = s:get_auth()
  return {'Authorization': 'token ' . token}
endfunction " }}}
function! s:get_authenticated_user() abort " {{{
  let [username, token] = s:get_auth()
  return username
endfunction " }}}
function! s:authorize(username, settings) abort " {{{
  let settings = extend({}, a:settings)
  redraw
  echohl Title
  echo  'Authorization:'
  echohl None
  echo  'A GitHub password of "' . a:username . '" is required. '
  echon 'The password is used only for obtaining an access token from GitHub '
  echon 'API and never be stored.'
  let password = inputsecret('GitHub password for ' . a:username . ': ')
  if empty(password)
    redraw
    echohl WarningMsg
    echon 'Canceled.'
    echohl None
    return
  endif

  redraw | echo 'Requesting an authorization token ...'
  let insecure_password = gista#vital#base64_encode(a:username . ':' . password)
  let params = {
        \   'scopes'   : ['gist'],
        \   'note'     : 'vim-gista@' . hostname(),
        \   'note_url' : 'http://github.com/lambdalisue/vim-gista/',
        \}
  let headers = {
        \ 'Authorization' : 'basic ' . insecure_password,
        \}
  let url = s:get_api_url('authorizations')
  " it seems that authorization does not work with Python client.
  let res = gista#vital#post(url, params, headers, settings)

  " is a tow-factor authentication required?
  let h = filter(res.header, 'stridx(v:val, "X-GitHub-OTP:") == 0')
  if len(h)
    redraw
    echohl Title
    echo  'Two-factor authentication:'
    echohl None
    echo  'It seems that "' . a:username . '" enabled a two-factor authentication. '
    echon 'Please input a six digits two-factor authentication code.'
    let otp = input('Two-factor authentication code: ')
    if len(otp) == 0
      redraw
      echohl WarningMsg
      echo 'Canceled.'
      echohl None
      return
    endif
    " re-authorize with OTP
    let headers["X-GitHub-OTP"] = otp
    let res = gista#vital#post(url, params, headers, settings)
  endif

  if res.status == 201
    return [a:username, res.content.token]
  else
    redraw
    echohl WarningMsg
    echo  'Authorization has failed:'
    echohl None
    echo  res.status . ' ' . res.statusText . '. '
    if has_key(res.content, 'message')
      echo 'Message: "' . res.content.message . '"'
    endif
  endif
  " fail to authorize
  return
endfunction " }}}
function! s:authorize2(token, settings) abort " {{{
  " it seems that authorization does not work with Python client.
  let settings = extend({}, a:settings))
  redraw | echo 'Confirming the personal access token ...'
  let res = gista#vital#get(s:get_api_url('user'), {}, {
        \ 'Authorization': 'token ' . a:token
        \}, settings)
  if res.status == 200
    return [res.content.login, a:token]
  else
    redraw
    echohl WarningMsg
    echo  'Authorization has faield:'
    echohl None
    echo  res.status . ' ' . res.statusText . '. '
    if has_key(res.content, 'message')
      echo 'Message: "' . res.content.message . '"'
    endif
  endif
  return
endfunction " }}}
function! s:get_gists_cache(name) abort " {{{
  if !exists('s:gists_cache_dict')
    if !exists('s:gists_cache_directory')
      let value = g:gista#gists_cache_directory
      let s:gists_cache_directory = fnamemodify(expand(value), ':p')
    endif
    let s:gists_cache_dict = {}
  endif
  if !has_key(s:gists_cache_dict, a:name)
    let s:gists_cache_dict[a:name] = gista#modules#cache#new(
          \ a:name, 
          \ s:gists_cache_directory, {
          \   'default': [],
          \})
  endif
  return s:gists_cache_dict[a:name]
endfunction " }}}


" Authentication
function! gista#raw#is_authenticated() abort " {{{
  return s:is_authenticated()
endfunction " }}}
function! gista#raw#get_authenticated_user() abort " {{{
  return s:get_authenticated_user()
endfunction " }}}
function! gista#raw#get_anonymous_header() abort " {{{
  return s:get_anonymous_header()
endfunction " }}}
function! gista#raw#login(...) abort " {{{
  let username = get(a:000, 0, s:get_authenticated_user())
  let settings = get(a:000, 1, {})
  if !s:is_authenticated() && empty(username)
    " the user have not authenticated yet so use default username
    let username = get(g:, 'gista#github_user',
                 \ get(g:, 'github_user', ''))
  elseif s:is_authenticated() && username == s:get_authenticated_user()
    " the user have already logged in
    return s:get_authenticated_header()
  endif
  if empty(username)
    redraw
    echohl Title
    echo  'GitHub Login:'
    echohl None
    echo  'Please input a Personal Access Token (PAT) or GitHub username. '
    echon 'If you input a PAT, the username will be automatically determined. '
    echo  'You can set default username (but not PAT) with "g:gista#github_user".'
    let username = input('Personal Access Token or Username: ')
    if len(username) == 0
      redraw
      echohl WarningMsg
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
      let ret = s:authorize2(username, settings)
      if !empty(ret)
        " authorize2 will return real login name
        let username = ret[0]
        let token = ret[1]
      endif
    else
      let ret = s:authorize(username, settings)
      if !empty(ret)
        let token = ret[1]
      endif
    endif

    if !empty(token)
      let token_filename = s:get_tokens().filename
      redraw
      echohl Title
      echo  'Logged into GitHub:'
      echohl None
      echo  'A login information of "' . username . '" is stored in a "'
      echon token_filename . '". '
      echon 'Run gista#raw#logout() to revoke the login information.'
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
function! gista#raw#logout(...) abort " {{{
  let permenently = get(a:000, 0, 0)
  if gista#raw#is_authenticated()
    let save_username = s:get_authenticated_user()
    call s:set_auth('', '')

    redraw
    let token_filename = s:get_tokens().filename
    if permenently
      call s:get_tokens().remove(save_username)
      echohl Title
      echo  'Permanently logged out from GitHub:'
      echohl None
      echo  printf('A login information of "%s" is removed from a "%s". ',
            \ save_username,
            \ token_filename
            \)
      echon 'Run gista#raw#login() to login again.'
    else
      echohl Title
      echo  'Temporary logged out from GitHub:'
      echohl None
      echo  printf('A login information of "%s" have not removed from a "%s". ',
            \ save_username,
            \ token_filename
            \)
      echon 'Run gista#raw#logout(1) to logged out permanently or '
      echon 'run gista#raw#login() to login again (No password required).'
    endif
  endif
endfunction " }}}

" API
function! gista#raw#get(gistid, ...) abort " {{{
  let settings = extend({
        \ 'anonymous': 0,
        \}, get(a:000, 0, {}))
  if settings.anonymous
    let header = s:get_anonymous_header()
  else
    let header = gista#raw#login()
    if empty(header)
      return {}
    endif
  endif

  redraw | echo 'Requesting gist (' . a:gistid . ') ...'
  let request_settings = gista#vital#omit(settings, [
        \ 'anonymous',
        \])
  return gista#vital#get(
        \ s:get_api_url('gists', a:gistid),
        \ {}, 
        \ header,
        \ request_settings)
endfunction " }}}
function! gista#raw#gets(lookup, ...) abort " {{{
  let settings = extend({
        \ 'page': -1,
        \ 'since': '',
        \ 'recursive': -1,
        \ 'nocache': 0,
        \ 'anonymous': 0,
        \}, get(a:000, 0, {}))
  " automatically assign settings
  if settings.page == -1 && settings.recursive == -1
    " default values are page=1, recursive=1
    let settings.page = 1
    let settings.recursive = 1
  elseif settings.page == -1
    " if recursive is specified, page=1
    let settings.page = 1
  elseif settings.recursive == -1
    " if page is specified, recursive=0
    let settings.recursive = 0
  endif
  if settings.recursive && settings.page != 1
    redraw
    echohl WarningMsg
    echo  'Conflicted options'
    echohl None
    echo  '"recursive" mode cannot be used when "page" is specified.'
    return {}
  elseif settings.anonymous && a:lookup == 'starred'
    redraw
    echohl WarningMsg
    echo  'Conflicted options'
    echohl None
    echo  '"anonymous" user does not have any "starred" gists.'
    return {}
  endif
  if settings.anonymous
    let header = s:get_anonymous_header()
  else
    let header = gista#raw#login()
    if empty(header)
      return {}
    endif
  endif
  let username = s:get_authenticated_user()
  if !settings.anonymous && (a:lookup == username || a:lookup == '')
    let url = s:get_api_url('gists')
    let cache = s:get_gists_cache(username . '.all')
    let cached_gists = cache.get('gists')
  elseif a:lookup == 'starred'
    let url = s:get_api_url('gists', 'starred')
    let cache = s:get_gists_cache(username . '.starred')
    let cached_gists = cache.get('gists')
  elseif a:lookup == 'public'
    let url = s:get_api_url('gists', a:lookup)
    let cached_gists = []
    " recursive in public gists is too heavy
    let settings.recursive = 0
  else
    let url = s:get_api_url('users', a:lookup, 'gists')
    let cache = s:get_gists_cache(a:lookup . '.public')
    let cached_gists = cache.get('gists')
  endif

  let terminal = -1
  let params = gista#vital#pick(settings, ['page', 'since'])
  let params = filter(params, '!empty(v:val)')
  if exists('cache') && !empty(cache.last_updated)
    " fetch gists newer than cache last updated
    let params = extend({
          \ 'since': cache.last_updated,
          \}, params)
  endif


  let request_settings = gista#vital#omit(settings, [
        \ 'page',
        \ 'since',
        \ 'recursive',
        \ 'nocache',
        \ 'anonymous',
        \])
  let request_settings['default_content'] = '[]'
  let loaded_gists = []
  redraw
  if settings.nocache
    let cached_gists = []
    let params = {'page': params.page}
    echo 'Requesting gists (No cache used) ...'
  elseif !empty(get(params, 'since', ''))
    echo 'Requesting gists updated since' params.since '...'
  else
    echo 'Requesting gists ...'
  endif
  while terminal == -1 || params.page <= terminal
    let res = gista#vital#get(url, params, header, request_settings)
    if res.status != 200
      break
    elseif terminal == -1 && settings.recursive
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
    call map(ct, 'gista#vital#pick(v:val, [
          \ "id","description","public","files",
          \ "created_at", "updated_at",
          \])')
    " filter files to reduce cache size
    call map(ct, 'extend({"files": map(v:val.files, "{}")}, v:val)')
    let loaded_gists = gista#vital#concat([loaded_gists, ct])

    if !settings.recursive || terminal <= 0 
      break
    endif

    redraw
    if settings.nocache
      echo 'Requesting gists (No cache used) ...'
    elseif !empty(get(params, 'since', ''))
      echo 'Requesting gists updated since' params.since '...'
    else
      echo 'Requesting gists ...'
    endif
    echon params.page . '/' . terminal . ' pages has been loaded (Ctrl-C to cancel)'

    let params.page += 1
  endwhile

  if res.status == 200
    if !(empty(cached_gists) || empty(loaded_gists))
      " remove duplicated gists (keep newly loaded gists)
      for loaded_gist in loaded_gists
        call filter(cached_gists, 'loaded_gist.id!=v:val.id')
      endfor
    endif
    let res.cached_gists = cached_gists
    let res.loaded_gists = loaded_gists
    let res.content = loaded_gists + cached_gists
    if exists('cache') && settings.recursive
      call cache.set('gists', res.content)
    endif
  endif
  return res
endfunction " }}}
function! gista#raw#post(filenames, contents, ...) abort " {{{
  let settings = extend({
        \ 'description': '',
        \ 'public': 1,
        \ 'anonymous': 0,
        \}, get(a:000, 0, {}))
  if settings.anonymous
    let header = s:get_anonymous_header()
  else
    let header = gista#raw#login()
    if empty(header)
      return {}
    endif
  endif

  let gist = {
        \ 'description': settings.description,
        \ 'public': (settings.public ? gista#vital#true() : gista#vital#false()),
        \ 'files': {},
        \}
  for [filename, content] in gista#vital#zip(a:filenames, a:contents)
    let gist.files[filename] = {'content': content}
  endfor

  redraw | echo 'Posting gist ...'
  let request_settings = gista#vital#omit(settings, [
        \ 'description',
        \ 'public',
        \ 'anonymous',
        \])
  let res = gista#vital#post(s:get_api_url('gists'), gist, header, request_settings)
  return res
endfunction " }}}
function! gista#raw#patch(gistid, partial, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#raw#login()
  if empty(header)
    return {}
  endif

  redraw | echo 'Patching gist (' . a:gistid . ') ...'
  let request_settings = gista#vital#omit(settings, [])
  let res = gista#vital#patch(s:get_api_url('gists', a:gistid), a:partial, header, request_settings)
  return res
endfunction " }}}
function! gista#raw#remove(gistid, filenames, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#raw#login()
  if empty(header)
    return {}
  endif

  let partial = {
        \ 'files': {},
        \}
  for filename in a:filenames
    let partial.files[filename] = gista#vital#null()
  endfor

  redraw | echo 'Removing "' . join(a:filenames, ",") . '" from the gist '
  echon '(' . a:gistid . ') ...'
  let request_settings = gista#vital#omit(settings, [])
  let res = gista#vital#patch(s:get_api_url('gists', a:gistid),
        \ partial, header, request_settings)
  return res
endfunction " }}}
function! gista#raw#delete(gistid, ...) abort " {{{
  let settings = extend({
        \ 'delete_from_cache': 1,
        \}, get(a:000, 0, {}))
  let header = gista#raw#login()
  if empty(header)
    return {}
  endif

  redraw | echo 'Deleting gist (' . a:gistid . ') ...'
  let request_settings = gista#vital#omit(settings, [])
  let res = gista#vital#delete(s:get_api_url('gists', a:gistid), header, request_settings)
  if settings.delete_from_cache && res.status == 204
    " remove deleted gist entry from the cache
    redraw
    echo  'Deleting the gist from caches ...'
    let suffixes = ['.all', '.starred', '.public']
    let username = s:get_authenticated_user()
    for suffix in suffixes
      let cache = s:get_gists_cache(username . suffix)
      for [kind, gists] in items(cache.cached)
        let gists = filter(copy(gists),
              \ printf('v:val.id !=# "%s"', a:gistid)
              \)
        let cache.cached[kind] = gists
      endfor
      " save cache
      call cache.save()
    endfor
  endif
  return res
endfunction " }}}
function! gista#raw#star(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#raw#login()
  if empty(header)
    return {}
  endif

  redraw | echo 'Star gist (' . a:gistid . ') ...'
  let request_settings = gista#vital#omit(settings, [])
  let res = gista#vital#put(s:get_api_url('gists', a:gistid, 'star'),
        \ {}, header, request_settings)
  return res
endfunction " }}}
function! gista#raw#unstar(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#raw#login()
  if empty(header)
    return {}
  endif

  redraw | echo 'Unstar gist (' . a:gistid . ') ...'
  let request_settings = gista#vital#omit(settings, [])
  let res = gista#vital#delete(s:get_api_url('gists', a:gistid, 'star'),
        \ header, request_settings)
  return res
endfunction " }}}
function! gista#raw#is_starred(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#raw#login()
  if empty(header)
    return {}
  endif

  redraw | echo 'Check whether if the gist (' . a:gistid . ') is starred...'
  let request_settings = gista#vital#omit(settings, [])
  let res = gista#vital#get(s:get_api_url('gists', a:gistid, 'star'),
        \ {}, header, request_settings)
  return res
endfunction " }}}
function! gista#raw#fork(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#raw#login()
  if empty(header)
    return {}
  endif

  redraw | echo 'Forking gist (' . a:gistid . ') ...'
  let request_settings = gista#vital#omit(settings, [])
  let res = gista#vital#post(s:get_api_url('gists', a:gistid, 'forks'),
        \ {}, header, request_settings)
  return res
endfunction " }}}
function! gista#raw#forks(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let header = gista#raw#login()
  if empty(header)
    return {}
  endif

  redraw | echo 'Listing forks of gist (' . a:gistid . ') ...'
  let request_settings = gista#vital#omit(settings, [])
  let res = gista#vital#get(s:get_api_url('gists', a:gistid, 'forks'),
        \ {}, header, request_settings)
  return res
endfunction " }}}

" Cache utils
function! gista#raw#get_gists_cache(username) " {{{
  return s:get_gists_cache(a:username)
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
