let s:save_cpo = &cpo
set cpo&vim


let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! gista#command#fork#call(...) abort
  let options = extend({
        \ 'gistid': '',
        \}, get(a:000, 0, {}))
  try
    let gistid = gista#resource#local#get_valid_gistid(empty(options.gist)
          \ ? options.gistid
          \ : options.gist.id
          \)
    let gist = gista#resource#remote#fork(gistid, options)
    silent call gista#util#doautocmd('CacheUpdatePost')
    let client = gista#client#get()
    call gista#util#prompt#indicate(options, printf(
          \ 'A gist %s in %s is forked to %s',
          \ gistid, client.apiname, gist.id,
          \))
    return [gist, gistid]
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return [{}, gistid]
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista fork',
          \ 'description': 'Fork an existing gist',
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#option#complete_gistid'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#fork#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#option#assign_gistid(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#fork#default_options),
        \ options,
        \)
  call gista#command#fork#call(options)
endfunction
function! gista#command#fork#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#fork', {
      \ 'default_options': {},
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
