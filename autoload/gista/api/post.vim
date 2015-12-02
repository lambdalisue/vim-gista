let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')
let s:J = s:V.import('Web.JSON')

let s:current_gistid = ''

function! s:set_current_gistid(value) abort " {{{
  let s:current_gistid = a:value
endfunction " }}}

function! gista#api#post#get_current_gistid() abort " {{{
  return s:current_gistid
endfunction " }}}
function! gista#api#post#call(client, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'description': g:gista#api#post#interactive_description,
        \ 'public': g:gista#api#post#default_public,
        \ 'filenames': [],
        \ 'contents': [],
        \}, get(a:000, 0, {})
        \)
  let anonymous = gista#api#get_current_anonymous()
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
  for [filename, content] in s:L.zip(options.filenames, options.contents)
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
          \ 'Posting a gist to %s%s ...',
          \ a:client.name,
          \ anonymous
          \   ? ' as an anonymous user'
          \   : ''
          \))
  endif
  let url = 'gists'
  let res = a:client.post(url, gist, {}, {
        \ 'verbose': options.verbose,
        \ 'anonymous': anonymous,
        \})
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? {} : s:J.decode(res.content)
  if res.status != 201
    call gista#util#prompt#throw(
          \ printf('%s: %s', res.status, res.statusText),
          \ get(res.content, 'message', ''),
          \)
  endif
  call s:set_current_gistid(res.content.id)
  call a:client.content_cache.set(res.content.id, res.content)
  " update entry cache as well if post as non anonymous user
  if !anonymous
    call gista#gist#update_entry_cache(
          \ a:client,
          \ a:client.get_authorized_username(),
          \ res.content,
          \)
    call gista#gist#update_entry_cache(
          \ a:client,
          \ 'starred',
          \ res.content,
          \)
  endif
  return res.content
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
