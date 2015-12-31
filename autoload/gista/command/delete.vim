let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

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
function! gista#command#delete#call(...) abort
  let options = extend({
        \ 'gistid': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let gistid = gista#meta#get_valid_gistid(options.gistid)
    let gist   = gista#api#gists#delete(gistid, options)
    let client = gista#api#get_current_client()
    " TODO
    " Handle existing buffer which open a file content of the deleted gist
    return gist
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return ''
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista delete',
          \ 'description': 'Delete a gist',
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#meta#complete_gistid'),
          \   'type': s:A.types.value,
          \})
    call s:parser.add_argument(
          \ '--remote', '-r',
          \ 'Delete a gist from remote as well', {
          \   'type': s:A.types.value,
          \})
    call s:parser.add_argument(
          \ '--cache',
          \ 'Delete a gist only from the cache', {
          \   'default': 0,
          \   'deniable': 1,
          \})
  endif
  return s:parser
endfunction
function! gista#command#delete#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#meta#assign_gistid(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#delete#default_options),
        \ options,
        \)
  call gista#command#delete#call(options)
endfunction
function! gista#command#delete#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#delete', {
      \ 'default_options': {},
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
