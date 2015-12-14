let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')
let s:J = s:V.import('Web.JSON')

function! gista#api#post#post(filenames, contents, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'description': g:gista#api#post#interactive_description,
        \ 'public': g:gista#api#post#default_public,
        \}, get(a:000, 0, {})
        \)
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()

  " Description
  let description = ''
  if type(options.description) == type(0)
    if options.description
      let description = gista#util#prompt#ask(
            \ 'Please input a description of a gist: ',
            \)
    endif
  else
    let description = options.description
  endif
  if empty(description) && !g:gista#api#post#allow_empty_description
    call gista#util#prompt#throw(
          \ 'An empty description is not allowed',
          \ 'See ":help g:gista#api#post#allow_empty_description" for detail',
          \)
  endif

  " Create a gist instance
  let gist = {
        \ 'description': description,
        \ 'public': options.public ? s:J.true : s:J.false,
        \ 'files': {},
        \}
  for [filename, content] in s:L.zip(a:filenames, a:contents)
    if type(content) == type('')
      let gist.files[filename] = { 'content': content }
    elseif type(content) == type([])
      let gist.files[filename] = { 'content': join(content, "\n") }
    else
      let gist.files[filename] = content
    endif
    unlet content
  endfor

  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ 'Posting a gist to %s %s ...',
          \ client.apiname,
          \ empty(username)
          \   ? 'as an anonymous user'
          \   : username,
          \))
  endif

  let url = 'gists'
  let res = client.post(url, gist, {}, {
        \ 'verbose': options.verbose,
        \})
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:J.decode(res.content)
  if res.status != 201
    call gista#api#throw(res)
  endif

  let gist = gista#gist#mark_fetched(res.content)
  call client.content_cache.set(gist.id, gist)
  if !empty(username)
    call gista#gist#apply_to_entry_cache(
          \ client, gist.id,
          \ function('gista#gist#mark_fetched'),
          \)
    call gista#gist#apply_to_entry_cache(
          \ client, gist.id,
          \ function('gista#gist#unmark_modified'),
          \)
  endif
  return gist
endfunction " }}}

" Configure variables
call gista#define_variables('api#post', {
      \ 'interactive_description': 1,
      \ 'allow_empty_description': 0,
      \ 'default_public': 1,
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
