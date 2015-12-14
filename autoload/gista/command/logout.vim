let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! s:handle_exception(exception) abort " {{{
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
endfunction " }}}
function! gista#command#logout#call(...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'apiname': '',
        \}, get(a:000, 0, {}),
        \)
  try
    call gista#api#switch({
          \ 'verbose': options.verbose,
          \ 'apiname': options.apiname,
          \})
    let client = gista#api#get_current_client()
    call gista#util#prompt#echo(printf(
          \ 'Logout from %s',
          \ client.apiname,
          \))
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista logout',
          \ 'description': 'Logout from a specified API',
          \})
    call s:parser.add_argument(
          \ '--apiname',
          \ 'An API name', {
          \   'type': s:A.types.value,
          \   'complete': function('g:gista#api#complete_apiname'),
          \})
  endif
  return s:parser
endfunction " }}}
function! gista#command#logout#command(...) abort " {{{
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#logout#default_options),
        \ options,
        \)
  call gista#command#logout#call(options)
endfunction " }}}
function! gista#command#logout#complete(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction " }}}

call gista#define_variables('command#logout', {
      \ 'default_options': {},
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
