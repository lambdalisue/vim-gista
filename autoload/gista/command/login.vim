let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! s:handle_exception(exception) abort
  redraw
  let canceled_by_user_patterns = [
        \ '^vim-gista: Login canceled',
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
function! gista#command#login#call(...) abort
  let options = extend({
        \ 'verbose': 1,
        \ 'apiname': '',
        \ 'username': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let apiname = gista#client#get_valid_apiname(options.apiname)
    let username = gista#client#get_valid_username(apiname, options.username)
    call gista#client#set(apiname, {
          \ 'verbose': options.verbose,
          \ 'username': username,
          \})
    let client = gista#client#get()
    call gista#util#prompt#echo(printf(
          \ 'Login into %s as %s',
          \ client.apiname,
          \ client.get_authorized_username(),
          \))
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista login',
          \ 'description': 'Login as a specified username to a specified API',
          \})
    call s:parser.add_argument(
          \ '--apiname',
          \ 'An API name', {
          \   'complete': function('gista#option#complete_apiname'),
          \})
    call s:parser.add_argument(
          \ '--username',
          \ 'A username of an API account', {
          \   'complete': function('gista#option#complete_username'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#login#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#login#default_options),
        \ options,
        \)
  call gista#command#login#call(options)
endfunction
function! gista#command#login#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#login', {
      \ 'default_options': {},
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
