let s:save_cpo = &cpoptions
set cpoptions&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

let s:parser = s:A.new({
      \ 'name': 'Gista post',
      \ 'description': 'Post file contents to a gist',
      \})
call s:parser.add_argument(
      \ '--baseurl',
      \ 'A baseurl or alias of a gist API.',
      \)
call s:parser.add_argument(
      \ '--username',
      \ 'A username of a gist API.', {
      \   'conflicts': ['anonymous'],
      \})
call s:parser.add_argument(
      \ '--anonymous',
      \ 'Post a gist as an anonymous gist', {
      \   'conflicts': ['private', 'public', 'username'],
      \})
call s:parser.add_argument(
      \ '--private', '-p',
      \ 'Post a gist as a private gist', {
      \   'conflicts': ['anonymous', 'public'],
      \})
call s:parser.add_argument(
      \ '--public', '-P',
      \ 'Post a gist as a public gist', {
      \   'conflicts': ['anonymous', 'private'],
      \})
call s:parser.add_argument(
      \ '--description', '-d',
      \ 'A description of a gist',
      \)
function! s:parser.post_validate(opts) abort " {{{
  if has_key(a:opts, 'private')
    let a:opts.public = !a:opts.private
    unlet a:opts.private
  endif
endfunction " }}}

function! gista#command#post#exec(filenames, contents, ...) abort " {{{
  let options = extend({
        \ 'anonymous': 0,
        \ 'description': '',
        \ 'interactive_description':
        \   g:gista#command#post#interactive_description,
        \ 'interactive_visibility':
        \   g:gista#command#post#interactive_visibility,
        \ 'allow_empty': g:gista#command#post#allow_empty,
        \}, get(a:000, 0, {})
        \)
  let baseurl = gista#client#get_baseurl(get(options, 'baseurl', ''))
  let client = gista#client#get(baseurl)
  if !options.anonymous
    if !gista#client#login_required(client, options)
      " login failed.
      call gista#prompt#warn(
            \ 'To post a gist as an anonymous gist, use "--anonymous" option.'
            \)
      return
    endif
  endif
  " description
  if empty(options.description) && options.interactive_description
    redraw
    call gista#prompt#info('Please write a description of the gist')
    let options.description = gista#prompt#ask('Description: ')
  endif
  if empty(options.description) && !options.allow_empty
    redraw
    if !options.interactive_description
      " use may not notice why the posting is canceled if no interactive
      " description is allowed so show extra message to explain why.
      call gista#prompt#warn('An empty description is not allowed.')
    endif
    call gista#prompt#warn('Canceled.')
    return
  endif
  " visibility (public/private)
  if !has_key(options, 'public') && !options.anonymous
    if options.interactive_visibility
      redraw
      let options.public = gista#prompt#asktf(
            \ 'Do you want to post a gist as a PRIVATE gist?',
            \ g:gista#command#post#post_as_private ? 'yes' : 'no',
            \)
    else
      let options.public = !g:gista#command#post#post_as_private
    endif
  endif
  let ret = gista#operation#post(client, a:filenames, a:contents, options)
  if ret.status != 201
    redraw
    call gista#prompt#error(
          \ ret.status,
          \ ret.statusText,
          \)
    if has_key(ret.content, 'message')
      call gista#prompt#echo(ret.content.message)
    endif
  endif
endfunction " }}}
function! gista#command#post#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#post#default_options),
        \ options,
        \)
  " extend filenames and contents
  if !empty(options.__unknown__)
    " use values of '__unknown__' as filenames and contents
    let filenames = filter(copy(options.__unknown__), 'filereadable(v:val)')
    let contents  = map(copy(filenames), 'readfile(v:val)')
  else
    " use content of the current buffer
    let filenames = [expand('%')]
    let contents  = [getline(1, '$')]
  endif
  " use only the tail part of the filename (basename)
  call map(filenames, 'fnamemodify(v:val, ":t")')
  call gista#command#post#exec(filenames, contents, options)
endfunction " }}}
function! gista#command#post#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}


call gista#util#init('command#post', {
      \ 'default_options': {},
      \ 'interactive_description': 1,
      \ 'interactive_visibility': 1,
      \ 'post_as_private': 0,
      \ 'allow_empty': 0,
      \})

let &cpoptions = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
