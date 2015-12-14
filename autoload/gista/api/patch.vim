let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')
let s:J = s:V.import('Web.JSON')

function! gista#api#patch#patch(gistid, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'fresh': 0,
        \ 'description': g:gista#api#patch#interactive_description,
        \ 'filenames': [],
        \ 'contents': [],
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  if empty(username)
    call gista#util#prompt#throw(
          \ 'Patching a gist cannot be performed as an anonymous user',
          \)
  endif

  let gist = gista#api#get#get(a:gistid, {
        \ 'verbose': options.verbose,
        \ 'fresh': options.fresh,
        \})

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
  if empty(description) && !g:gista#api#patch#allow_empty_description
    call gista#util#prompt#throw(
          \ 'An empty description is not allowed',
          \ 'See ":help g:gista#api#patch#allow_empty_description" for detail',
          \)
  endif

  " Create a gist instance
  let partial_gist = {
        \ 'description': description,
        \ 'files': {},
        \}
  for [filename, content] in s:L.zip(options.filenames, options.contents)
    if type(content) == type('')
      let partial_gist.files[filename] = { 'content': content }
    elseif type(content) == type([])
      let partial_gist.files[filename] = { 'content': join(content, "\n") }
    elseif type(content) == type(0) && !content
      let partial_gist.files[filename] = s:J.null
    else
      let partial_gist.files[filename] = content
    endif
    unlet content
  endfor

  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Patching a gist "%s" to %s as %s...',
          \ gist.id,
          \ client.apiname,
          \ username,
          \))
  endif
  let res = client.patch('gists/' . gist.id, partial_gist, {}, {
        \ 'verbose': options.verbose,
        \})
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:J.decode(res.content)
  if res.status != 200
    call gista#api#throw(res)
  endif

  let gist = gista#gist#mark_fetched(res.content)
  call client.content_cache.set(gist.id, gist)
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

" Configure variables
call gista#define_variables('api#patch', {
      \ 'interactive_description': 0,
      \ 'allow_empty_description': 1,
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
