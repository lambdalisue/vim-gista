let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:J = s:V.import('Web.JSON')

" A content size limit for downloading via HTTP
" https://developer.github.com/v3/gists/#truncation
let s:SIZE_LIMIT = 10 * 1024 * 1024

function! s:get_available_gistids() abort " {{{
  let client = gista#api#get_current_client()
  let lookup = client.get_authorized_username()
  let lookup = empty(lookup) ? 'public' : lookup
  let entries = client.entry_cache.get(lookup, [])
  return map(copy(entries), 'v:val.id')
endfunction " }}}
function! s:get_valid_gistid(gistid) abort " {{{
  call gista#util#validate#not_empty(
        \ a:gistid,
        \ 'A gist ID cannot be empty',
        \)
  call gista#util#validate#pattern(
        \ a:gistid, '^\w\{,20}\%(/\w\+\)\?$',
        \ 'A gist ID "%value" requires to follow "%pattern"'
        \)
  return a:gistid
endfunction " }}}
function! s:get_gistid(gistid) abort " {{{
  if empty(a:gistid)
    redraw
    let gistid = gista#util#prompt#ask(
          \ 'Please input a gist id: ', '',
          \ 'customlist,gista#api#get#complete_gistid',
          \)
  else
    let gistid = a:gistid
  endif
  return s:get_valid_gistid(gistid)
endfunction " }}}

function! s:get_available_filenames(gist) abort " {{{
  " Remove files more thant 10 MiB which cannot download with HTTP protocol
  return filter(
        \ keys(a:gist.files),
        \ 'a:gist.files[v:val].size < s:SIZE_LIMIT'
        \)
endfunction " }}}
function! s:get_valid_filename(gist, filename) abort " {{{
  call gista#util#validate#not_empty(
        \ a:filename,
        \ 'A filename cannot be empty',
        \)
  call gista#util#validate#exists(
        \ a:filename, s:get_available_filenames(a:gist),
        \ printf(
        \   'A filename "%s" is not found in "%s" or more than 10 MiB',
        \   a:gist.id, a:filename,
        \ ),
        \)
  return a:filename
endfunction " }}}
function! s:get_filename(gist, filename) abort " {{{
  if empty(a:filename)
    let available_filenames = s:get_available_filenames(a:gist)
    if len(available_filenames) == 0
      call gista#util#prompt#throw(
            \ printf(
            \   'No available files are found in a gist "%s".',
            \   a:gist.id
            \ ),
            \ 'Note that a file which is more than 10 MiB is not available.',
            \ printf(
            \   'You need to clone the gist via the URL "%s".',
            \   a:gist.git_pull_url
            \ ),
            \)
    elseif len(available_filenames) == 1
      let filename = available_filenames[0]
    else
      redraw
      let ret = gista#util#prompt#inputlist(
            \ 'Please select a filename: ',
            \ available_filenames,
            \)
      let filename = ret ? available_filenames[ret - 1] : ''
    endif
  else
    let filename = a:filename
  endif
  return s:get_valid_filename(a:gist, filename)
endfunction " }}}

function! gista#api#get#get_cache(gistid) abort " {{{
  let client = gista#api#get_current_client()
  let gistid = s:get_gistid(a:gistid)
  return client.content_cache.get(gistid, {})
endfunction " }}}
function! gista#api#get#get(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'fresh': 0,
        \}, get(a:000, 0, {})
        \)
  let gist = gista#api#get#get_cache(a:gistid)
  if !empty(gist)
    if options.fresh &&gista#gist#is_modified(gist)
      if !gista#util#prompt#asktf(join([
          \ 'The changes of the gist content has not been posted yet.',
          \ 'Are you sure you want to overwrite the changes? ',
          \], "\n"))
        return gist
      endif
    elseif !options.fresh
      return gist
    endif
  endif

  let client = gista#api#get_current_client()
  let gistid = s:get_gistid(a:gistid)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Requesting a gist "%s" in %s %s ...',
          \ gistid,
          \ client.apiname,
          \ empty(client.get_authorized_username())
          \   ? 'as an anonymous user'
          \   : 'as ' . client.get_authorized_username(),
          \))
  endif
  let res = client.get('gists/' . gistid, {}, {}, {
        \ 'verbose': options.verbose,
        \})
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:J.decode(res.content)
  if res.status != 200
    call gista#api#throw(res)
  endif
  let gist = gista#gist#mark_fetched(res.content)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Updating content cache of a gist "%s" in %s...',
          \ gist.id,
          \ client.apiname,
          \))
  endif
  call client.content_cache.set(gist.id, gist)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Updating entry caches of a gist "%s" in %s...',
          \ gist.id,
          \ client.apiname,
          \))
  endif
  call gista#gist#apply_to_entry_cache(
        \ client, gist.id,
        \ function('gista#gist#mark_fetched'),
        \)
  call gista#gist#apply_to_entry_cache(
        \ client, gist.id,
        \ function('gista#gist#unmark_modified'),
        \)
  return gist
endfunction " }}}
function! gista#api#get#content(gist, filename, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'fresh': 0,
        \}, get(a:000, 0, {})
        \)
  let filename = s:get_filename(a:gist, a:filename)
  let file = get(a:gist.files, filename, {})
  if empty(file)
    call gista#util#prompt#throw(
          \ '404: Not found',
          \ printf(
          \   'A filename "%s" is not found in a gist "%s"',
          \   filename, a:gist.id,
          \ ),
          \)
  elseif file.truncated
    " request the file content if the content is truncated
    let client = gista#api#get_current_client()
    let res = client.get(file.raw_url, {}, {}, {
          \ 'verbose': options.verbose,
          \})
    if res.status != 200
      call gista#api#throw(res)
    endif
    let file.truncated = 0
    let file.content = res.content
  endif
  return {
        \ 'filename': filename,
        \ 'content': split(file.content, '\r\?\n'),
        \}
endfunction " }}}
function! gista#api#get#complete_gistid(arglead, cmdline, cursorpos, ...) abort " {{{
  return filter(
        \ s:get_available_gistids(),
        \ 'v:val =~# "^" . a:arglead',
        \)
endfunction " }}}
function! gista#api#get#complete_filename(arglead, cmdline, cursorpos, ...) abort " {{{
  let options = extend({
        \ 'gistid': '',
        \}, get(a:000, 0, {}),
        \)
  let clinet = gista#api#get_current_client()
  let gist = gista#api#get#get_cache(options.gistid)
  if empty(gist)
    return []
  endif
  let available_filenames = s:get_available_filenames(gist)
  return filter(available_filenames, 'v:val =~# "^" . a:arglead')
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
