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
          \ 'See ":help g:gista#command#post#allow_empty_description" for detail',
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
        \ 'description': g:gista#command#post#interactive_description,
        \ 'public': g:gista#command#post#default_public,
        \}, get(a:000, 0, {}),
        \)
  call s:interactive_description(options)
  let filename = fnamemodify(gista#meta#guess_filename('%'), ':t')
  let content  = join(call('getline', options.__range__), "\n")
  let options.filenames = [ filename ]
  let options.contents  = [
        \ { 'content': content },
        \]
  try
    let gist = gista#resource#gists#post(
          \ options.filenames,
          \ options.contents,
          \ options,
          \)
    let client = gista#client#get()
    let bufname = gista#command#open#bufname({
          \ 'gistid': gist.id,
          \ 'filename': filename,
          \})
    silent execute printf('file %s', bufname)
    call gista#util#doautocmd('CacheUpdatePost')
    redraw
    call gista#util#prompt#echo(printf(
          \ 'A content of the current buffer is posted to a gist %s in %s',
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
      \ 'allow_empty_description': 0,
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
