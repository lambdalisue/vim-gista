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
        \ 'filename': '',
        \ 'force': 0,
        \}, get(a:000, 0, {}),
        \)
  try
    let gistid = gista#meta#get_valid_gistid(options.gistid)
    if empty(options.filename)
      call gista#resource#gists#delete(gistid, options)
      call gista#util#doautocmd('CacheUpdatePost')
      let client = gista#client#get()
      redraw | call gista#util#prompt#echo(printf(
            \ 'A gist %s is removed from %s',
            \ gistid, client.apiname,
            \))
    else
      let filename = gista#meta#get_valid_filename(
            \ options.gistid, options.filename,
            \)
      call gista#resource#gists#patch(gistid, {
            \ 'force': options.force,
            \ 'files': { filename : {} },
            \})
      call gista#util#doautocmd('CacheUpdatePost')
      let client = gista#client#get()
      redraw | call gista#util#prompt#echo(printf(
            \ 'A %s is removed from a gist %s in %s',
            \ filename, gistid, client.apiname,
            \))
    endif
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista delete',
          \ 'description': 'Delete a gist or a file in a gist',
          \})
    call s:parser.add_argument(
          \ '--force',
          \ 'Delete a gist even a remote content of the gist is modified', {
          \   'default': 0,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#meta#complete_gistid'),
          \})
    call s:parser.add_argument(
          \ 'filename',
          \ 'A filename', {
          \   'complete': function('g:gista#meta#complete_filename'),
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
