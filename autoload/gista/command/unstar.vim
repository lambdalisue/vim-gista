let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! s:handle_exception(exception) abort " {{{
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
  call gista#util#prompt#error(a:exception)
endfunction " }}}
function! gista#command#unstar#call(...) abort " {{{
  let options = extend({
        \ 'gistid': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let gistid = gista#meta#get_valid_gistid(options.gistid)
    call gista#api#star#delete(gistid, options)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista unstar',
          \ 'description': 'Unstar an existing gist',
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#meta#complete_gistid'),
          \})
  endif
  return s:parser
endfunction " }}}
function! gista#command#unstar#command(...) abort " {{{
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#unstar#default_options),
        \ options,
        \)
  call gista#command#unstar#call(options)
endfunction " }}}
function! gista#command#unstar#complete(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction " }}}

call gista#define_variables('command#unstar', {
      \ 'default_options': {},
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
