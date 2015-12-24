let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')

function! gista#api#gists#cache#get(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Loading a gist %s in %s from the cache ...',
          \ a:gistid, client.apiname,
          \))
  endif
  let gist = extend({
        \ 'id': a:gistid,
        \ 'description': '',
        \ '_gista_fetched': 0,
        \ '_gista_modified': 0,
        \ '_gista_last_modified': '',
        \}, client.content_cache.get(a:gistid, {})
        \)
  return gist
endfunction " }}}
function! gista#api#gists#cache#list(lookup, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Loading gists of %s in %s from the cache ...',
          \ a:lookup, client.apiname,
          \))
  endif
  let entries = extend({
        \ 'lookup': a:lookup,
        \ 'since': '',
        \ 'entries': [],
        \ '_gista_fetched': 0,
        \ '_gista_modified': 0,
        \ '_gista_last_modified': '',
        \}, client.entry_cache.get(a:lookup, {}),
        \)
  return entries
endfunction " }}}
function! gista#api#gists#cache#patch(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'description': g:gista#api#gists#patch_interactive_description,
        \ 'filenames': [],
        \ 'contents': [],
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let gist = gista#api#gists#cache#get(a:gistid, options)

  " Description
  let description = gist.description
  if type(options.description) == type(0)
    if options.description
      let description = gista#util#prompt#ask(
            \ 'Please input a description of a gist: ',
            \ gist.description,
            \)
    endif
  else
    let description = options.description
  endif
  if empty(description) && !g:gista#api#gists#patch_allow_empty_description
    call gista#util#prompt#throw(
          \ 'An empty description is not allowed',
          \ 'See ":help g:gista#api#gists#patch_allow_empty_description" for detail',
          \)
  endif
  " Update a gist instance
  let gist._gista_modified = 1
  let gist.files = get(gist, 'files', {})
  let gist.description = description
  for [filename, content] in s:L.zip(options.filenames, options.contents)
    let gist.files[filename] = content
  endfor
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Updating a cache of a gist %s in %s ...',
          \ gist.id, client.apiname,
          \))
  endif
  call client.content_cache.set(gist.id, gist)
  return gist
endfunction " }}}
function! gista#api#gists#cache#delete(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let gist = gista#api#gists#cache#get(a:gistid, options)
  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Deleting a cache of a gist %s in %s ...',
          \ gist.id, client.apiname,
          \))
  endif
  call client.content_cache.remove(gist.id)
  " TODO
  " Remove from entry_cache as well
  return gist
endfunction " }}}
function! gista#api#gists#cache#content(gist, filename, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'fresh': 0,
        \}, get(a:000, 0, {})
        \)
  let file = get(a:gist.files, a:filename, {})
  if empty(file)
    call gista#util#prompt#throw(
          \ '404: Not found',
          \ printf(
          \   'A filename "%s" is not found in a gist "%s"',
          \   a:filename, a:gist.id,
          \ ),
          \)
  endif
  return {
        \ 'filename': a:filename,
        \ 'content': split(file.content, '\r\?\n'),
        \ 'truncated': file.truncated,
        \}
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
