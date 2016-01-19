let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! gista#command#status#call(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let client = gista#client#get()
  let gista = gista#get('%')
  let messages = [
        \ '=== Global ===',
        \ printf('API name : %s', client.apiname),
        \ printf('Username : %s', client.get_authorized_username()),
        \ ' ',
        \ '=== Local ===',
        \ printf('API name : %s', get(gista, 'apiname', '')),
        \ printf('Username : %s', get(gista, 'username', '')),
        \ printf('GistID   : %s', get(gista, 'gistid', '')),
        \ printf('Filename : %s', get(gista, 'filename', '')),
        \]
  call gista#util#prompt#echo(join(messages, "\n"))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista status',
          \ 'description': 'Show current status of gista',
          \})
  endif
  return s:parser
endfunction
function! gista#command#status#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#status#default_options),
        \ options,
        \)
  call gista#command#status#call(options)
endfunction
function! gista#command#status#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#status', {
      \ 'default_options': {},
      \})



let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
