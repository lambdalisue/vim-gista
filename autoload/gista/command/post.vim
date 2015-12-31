let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! s:interactive_description(options) abort
  if type(a:options.description) == type(0)
    if a:options.description
      unlet a:options.description
      let a:options.description = gista#util#prompt#ask(
            \ 'Please input a description of a gist: ',
            \)
    else
      unlet a:options.description
      return
    endif
  endif
  if empty(a:options.description) && !g:gista#command#post#allow_empty_description
    call gista#util#prompt#throw(
          \ 'An empty description is not allowed',
          \ 'See ":help g:gista#api#gists#patch_allow_empty_description" for detail',
          \)
  endif
endfunction


function! s:handle_exception(exception) abort
  redraw
  let canceled_by_user_patterns = [
        \ '^vim-gista: Login canceled',
        \ '^vim-gista: ValidationError:',
        \]
  for pattern in canceled_by_user_patterns
    if a:exception =~# pattern
      call gista#util#prompt#warn('Canceled')
      return
    endif
  endfor
  " else
  call gista#util#prompt#error(a:exception)
endfunction
function! gista#command#post#call(...) abort
  let options = extend({
        \ 'filenames': [],
        \ 'contents': [],
        \ 'description': g:gista#command#post#interactive_description,
        \ 'public': g:gista#command#post#default_public,
        \}, get(a:000, 0, {}),
        \)
  call s:interactive_description(options)
  try
    let gist = gista#api#gists#post(
          \ options.filenames, options.contents, options,
          \)
    let client = gista#api#get_current_client()
    for filename in options.filenames
      if bufexists(filename)
        call setbufvar(bufnr(filename), 'gista', {
              \ 'apiname': client.apiname,
              \ 'username': client.get_authorized_username(),
              \ 'gistid': gist.id,
              \ 'filename': fnamemodify(expand(filename), ':t'),
              \ 'content_type': 'raw',
              \})
      endif
    endfor
    call gista#util#doautocmd('CacheUpdatePost')
    redraw
    call gista#util#prompt#echo(printf(
          \ 'A gist %s is posted to %s',
          \ gist.id, client.apiname,
          \))
    return gist
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return ''
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista post',
          \ 'description': 'Post contents into a new gist',
          \})
    call s:parser.add_argument(
          \ '--description', '-d',
          \ 'A description of a gist', {
          \   'type': s:A.types.value,
          \})
    call s:parser.add_argument(
          \ '--public', '-p',
          \ 'Post a gist as a public gist', {
          \   'conflicts': ['private'],
          \})
    call s:parser.add_argument(
          \ '--private', '-P',
          \ 'Post a gist as a private gist', {
          \   'conflicts': ['public'],
          \})
    function! s:parser.hooks.post_validate(options) abort
      if has_key(a:options, 'private')
        let a:options.public = !a:options.private
        unlet a:options.private
      endif
    endfunction
  endif
  return s:parser
endfunction
function! gista#command#post#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#post#default_options),
        \ options,
        \)
  if empty(options.__unknown__)
    " Get content from the current buffer
    let filenames = [ gista#meta#guess_filename('%') ]
    let contents  = [
          \ call('getline', options.__range__)
          \]
  else
    let filenames = filter(
          \ map(options.__unknown__, 'expand(v:val)'),
          \ 'bufexists(v:val) || filereadable(v:val)',
          \)
    let contents = map(
          \ copy(filenames),
          \ 'bufexists(v:val) ? getbufline(v:val, 1, "$") : readfile(v:val)',
          \)
  endif
  let options.filenames = map(filenames, 'fnamemodify(v:val, ":t")')
  let options.contents  = map(contents, '{ "content": join(v:val, "\n") }')
  call gista#command#post#call(options)
endfunction
function! gista#command#post#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#post', {
      \ 'default_options': {},
      \ 'default_public': 1,
      \ 'interactive_description': 1,
      \ 'allow_empty_description': 1,
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
