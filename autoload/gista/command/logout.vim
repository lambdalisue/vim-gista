let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! gista#command#logout#call(...) abort
  let options = extend({
        \ 'apiname': '',
        \}, get(a:000, 0, {}))
  try
    let apiname = gista#client#get_valid_apiname(options.apiname)
    call gista#client#set(apiname, {})
    let client = gista#client#get()
    call gista#util#prompt#echo(printf(
          \ 'Logout from %s',
          \ client.apiname,
          \))
    return [apiname]
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return [apiname]
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista logout',
          \ 'description': 'Logout from a specified API',
          \})
    call s:parser.add_argument(
          \ '--apiname',
          \ 'An API name', {
          \   'complete': function('gista#option#complete_apiname'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#logout#command(...) abort
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
endfunction
function! gista#command#logout#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#logout', {
      \ 'default_options': {},
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
