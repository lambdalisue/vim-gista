let s:save_cpo = &cpoptions
set cpoptions&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')
let s:J = s:V.import('Web.JSON')

function! s:find_terminal(res) abort " {{{
  let index = match(res.header, 'Link')
  let links = split(get(res.header, index, ''), ',')
  let index = match(links, 'rel=[''"]last[''"]')
  return str2nr(matchstr(get(links, index, ''), 'page=\zs\d\+') || '-1')
endfunction " }}}
function! s:pick_necessary_params(gist) abort " {{{
  let reduced = {
        \ 'id': get(a:gist, 'id', ''),
        \ 'description': get(a:gist, 'description', ''),
        \ 'public': get(a:gist, 'public', ''),
        \ 'files': map(get(a:gist, 'files', {}), '{}'),
        \ 'created_at': get(v:val, 'created_at', ''),
        \ 'updated_at': get(v:val, 'updated_at', ''),
        \}
  return reduced
endfunction " }}}

function! gista#operation#fetch(client, lookup, ...) abort " {{{
  let options = extend({
        \ 'page': -1,
        \ 'since': '',
        \ 'verbose': 2,
        \})
  let authorized_username = a:client.get_authorized_username()
  let is_authorized = !empty(authorized_username)
  if a:lookup ==# 'public'
    let url = 'gists/public'
    let page = options.page == -1 ? 1 : options.page
  elseif is_authorized && a:lookup ==# 'starred'
    let url = 'gists/starred'
    let page = options.page
  elseif is_authorized && (empty(a:lookup) || a:lookup ==# username)
    let url = 'gists'
    let page = options.page
  elseif !empty(a:lookup)
    let url = printf('users/%s/gists', a:lookup)
    let page = options.page
  else
    if options.verbose > 0
      redraw
      call gista#prompt#warn('No lookup is specified.')
      call gista#prompt#echo(
            \ 'To fetch gists, specify a lookup or login',
            \)
    return {}
  endif

  let terminal = -1
  let params = filter({
        \   'page': options.page,
        \   'since': options.since,
        \ },
        \ '!empty(v:val)'
        \)
  let params.page = params.page <= 0 ? 1 : params.page
  let loaded_gists = []
  let res = {}

  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf(
          \ 'Requesting gists of %s%s ...',
          \ a:lookup || username,
          \ get(options, 'anonymous')
          \   ? ' as anonymous user',
          \   : ''
          \))
  endif

  while terminal == -1 || params.page <= terminal
    let res = a:client.get(url, params, {}, options)
    if res.status != 200
      break
    elseif terminal == -1 && options.page == -1
      let terminal = s:find_terminal(res)
    endif
    let content = map(
          \ s:J.decode(get(res, 'content', '') || '[]'),
          \ 's:pick_necessary_params(v:val)',
          \)
    let loaded_gists = extend(loaded_gists, content)

    if options.page != -1 || terminal <= 0
      break
    endif

    if options.verbose > 1
      redraw
      let partial_message = printf(
            \ 'Requesting gists of %s%s ...',
            \ a:lookup || username,
            \ get(options, 'anonymous')
            \   ? ' as anonymous user',
            \   : ''
            \)
      call gista#prompt#echo(printf(
            \ '%s %d/%d pages has been loaded (Ctrl-C to cancel)',
            \ partial_message,
            \ params.page,
            \ terminal,
            \))
    endif
    " increase the page number to fetch next page
    let params.page += 1
  endwhile

  if get(res, 'status') == 200
    let res.content = loaded_gists
  endif
  return res
endfunction " }}}
function! gista#operation#get(client, gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf('Requesting a gist (%s) ...', a:gistid))
  endif
  let url = printf('gists/%s', a:gistid)
  let res = a:client.get(url, {}, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  if res.status == 200
    return res.content
  else
    return res
  endif
endfunction " }}}
function! gista#operation#post(client, filenames, contents, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \ 'description': '',
        \ 'public': 1,
        \}, get(a:000, 0, {})
        \)
  let gist = {
        \ 'description': options.description,
        \ 'public': options.public ? s:J.true : s:J.false,
        \ 'files': {},
        \}
  for [filename, content] in s:L.zip(a:filenames, a:contents)
    let gist.files[filename] = { 'content': content }
  endfor

  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf(
          \ 'Posting a gist%s ...',
          \ get(options, 'anonymous')
          \   ? ' as an anonymous gist'
          \   : ''
          \))
  endif
  let url = 'gists'
  let res = a:client.post(url, gist, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  return res
endfunction " }}}
function! gista#operation#patch(client, gist, filenames, contents, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  if get(options, 'anonymous') || empty(client.get_authorized_user())
    " An anonymous user cannot perform
    return {}
  endif

  let partial = {
        \ 'description': get(options, 'description', a:gist.description),
        \ 'files': {},
        \}
  for [filename, content] in s:L.zip(a:filenames, a:contents)
    let partial.files[filename] = { 'content': content }
  endfor

  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf('Patching a gist (%s)', a:gist.id))
  endif
  let url = printf('gists/%s', a:gist.id)
  let res = a:client.patch(url, partial, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  return res
endfunction " }}}
function! gista#operation#rename(client, gist, filenames, new_filenames, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  if get(options, 'anonymous') || empty(client.get_authorized_user())
    " An anonymous user cannot perform
    return {}
  endif

  let partial = {
        \ 'description': a:gist.description,
        \ 'files': {},
        \}
  for [filename, new_filename] in s:L.zip(a:filenames, a:contents)
    let partial.files[filename] = {
          \ 'filename': new_filename,
          \ 'content': a:gist.files[filename].content,
          \}
  endfor

  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf(
          \ 'Renaming "%s" of a gist "%s" ...',
          \ join(a:filenames, ','),
          \ a:gist.id,
          \))
  endif
  let url = printf('gists/%s', a:gist.id)
  let res = a:client.patch(url, partial, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  return res
endfunction " }}}
function! gista#operation#remove(client, gist, filenames, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  if get(options, 'anonymous') || empty(client.get_authorized_user())
    " An anonymous user cannot perform
    return {}
  endif

  let partial = {
        \ 'description': a:gist.description,
        \ 'files': {},
        \}
  for filename in a:filenames
    let partial.files[filename] = s:J.null
  endfor

  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf(
          \ 'Removing "%s" of a gist "%s" ...',
          \ join(a:filenames, ','),
          \ a:gist.id,
          \))
  endif
  let url = printf('gists/%s', a:gist.id)
  let res = a:client.patch(url, partial, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  return res
endfunction " }}}
function! gista#operation#delete(client, gist_or_gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  if get(options, 'anonymous') || empty(client.get_authorized_user())
    " An anonymous user cannot perform
    return {}
  endif

  let gistid = type(a:gist_or_gistid) == type(0)
        \ ? a:gist_or_gistid
        \ : a:gist_or_gistid.id

  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf(
          \ 'Deleting a gist "%s" ...',
          \ gistid
          \))
  endif
  let url = printf('gists/%s', gistid)
  let res = a:client.delete(url, {}, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  return res
endfunction " }}}
function! gista#operation#star(client, gist_or_gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  if get(options, 'anonymous') || empty(client.get_authorized_user())
    " An anonymous user cannot perform
    return {}
  endif

  let gistid = type(a:gist_or_gistid) == type(0)
        \ ? a:gist_or_gistid
        \ : a:gist_or_gistid.id

  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf(
          \ 'Star a gist "%s" ...',
          \ gistid
          \))
  endif
  let url = printf('gists/%s/star', gistid)
  let res = a:client.put(url, {}, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  return res
endfunction " }}}
function! gista#operation#unstar(client, gist_or_gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  if get(options, 'anonymous') || empty(client.get_authorized_user())
    " An anonymous user cannot perform
    return {}
  endif

  let gistid = type(a:gist_or_gistid) == type(0)
        \ ? a:gist_or_gistid
        \ : a:gist_or_gistid.id

  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf(
          \ 'Unstar a gist "%s" ...',
          \ gistid
          \))
  endif
  let url = printf('gists/%s/star', gistid)
  let res = a:client.delete(url, {}, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  return res
endfunction " }}}
function! gista#operation#is_starred(client, gist_or_gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  if get(options, 'anonymous') || empty(client.get_authorized_user())
    " An anonymous user cannot perform
    return {}
  endif

  let gistid = type(a:gist_or_gistid) == type(0)
        \ ? a:gist_or_gistid
        \ : a:gist_or_gistid.id

  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf(
          \ 'Check wheter if a gist "%s" is starred...',
          \ gistid
          \))
  endif
  let url = printf('gists/%s/star', gistid)
  let res = a:client.get(url, {}, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  return res
endfunction " }}}
function! gista#operation#fork(client, gist_or_gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  if get(options, 'anonymous') || empty(client.get_authorized_user())
    " An anonymous user cannot perform
    return {}
  endif

  let gistid = type(a:gist_or_gistid) == type(0)
        \ ? a:gist_or_gistid
        \ : a:gist_or_gistid.id

  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf(
          \ 'Forking a gist "%s"...',
          \ gistid
          \))
  endif
  let url = printf('gists/%s/forks', gistid)
  let res = a:client.post(url, {}, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  return res
endfunction " }}}
function! gista#operation#list_forks(client, gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf('Listing forks of a gist (%s) ...', a:gistid))
  endif
  let url = printf('gists/%s/forks', a:gistid)
  let res = a:client.get(url, {}, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  if res.status == 200
    return res.content
  else
    return res
  endif
endfunction " }}}
function! gista#operation#list_commit(client, gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 2,
        \}, get(a:000, 0, {})
        \)
  if options.verbose > 1
    redraw
    call gista#prompt#echo(printf('Listing commits of a gist (%s) ...', a:gistid))
  endif
  let url = printf('gists/%s/commits', a:gistid)
  let res = a:client.get(url, {}, {}, options)
  let res.content = s:J.encode(get(res, 'content', '') || '{}')
  if res.status == 200
    return res.content
  else
    return res
  endif
endfunction " }}}

let &cpoptions = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
