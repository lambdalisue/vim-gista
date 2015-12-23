let s:save_cpo = &cpo
set cpo&vim


let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! s:handle_exception(exception) abort " {{{
  redraw
  let canceled_by_user_patterns = [
        \ '^vim-gista: Login canceled',
        \ '^vim-gista: ValidationError: An API name cannot be empty',
        \ '^vim-gista: ValidationError: An API account username cannot be empty',
        \ '^vim-gista: ValidationError: A gist ID cannot be empty',
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
function! gista#command#commit#call(...) abort " {{{
  let options = extend({
        \ 'gistid': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let gist = gista#api#commit#list(
          \ options.gistid, options
          \)
    return gist
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return ''
  endtry
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista commit',
          \ 'description': 'Star an existing gist',
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#api#gists#complete_gistid'),
          \})
  endif
  return s:parser
endfunction " }}}
function! gista#command#commit#command(...) abort " {{{
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#patch#default_options),
        \ options,
        \)
  call gista#command#commit#call(options)
endfunction " }}}
function! gista#command#commit#complete(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction " }}}

call gista#define_variables('command#commit', {
      \ 'default_options': {},
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
