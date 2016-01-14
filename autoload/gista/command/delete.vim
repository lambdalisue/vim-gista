let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! gista#command#delete#call(...) abort
  let options = extend({
        \ 'gistid': '',
        \ 'force': 0,
        \ 'confirm': 1,
        \}, get(a:000, 0, {}),
        \)
  try
    let client = gista#client#get()
    let gistid = gista#option#get_valid_gistid(options)
    if options.confirm
      if !gista#util#prompt#asktf(printf(
            \ 'Remove %s in %s? ',
            \ gistid, client.apiname,
            \))
        call gista#util#prompt#throw('Cancel')
      endif
    endif
    call gista#resource#remote#delete(gistid, options)
    call gista#util#doautocmd('CacheUpdatePost')
    call gista#indicate(options, printf(
          \ 'A gist %s is deleted from %s',
          \ gistid, client.apiname,
          \))
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista delete',
          \ 'description': 'Delete a gist',
          \})
    call s:parser.add_argument(
          \ '--force',
          \ 'Delete a gist even a remote content of the gist is modified', {
          \   'default': 0,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ '--confirm',
          \ 'Confirm before delete', {
          \   'default': 1,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#option#complete_gistid'),
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
  call gista#option#assign_gistid(options, '%')
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
