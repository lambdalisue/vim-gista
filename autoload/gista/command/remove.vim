let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! s:handle_exception(exception) abort
  redraw
  let canceled_by_user_patterns = [
        \ '^vim-gista: Cancel',
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
function! gista#command#remove#call(...) abort
  let options = extend({
        \ 'gistid': '',
        \ 'filename': '',
        \ 'force': 0,
        \ 'confirm': 1,
        \}, get(a:000, 0, {}),
        \)
  try
    let client = gista#client#get()
    let gistid = gista#option#get_valid_gistid(options)
    let filename = gista#option#get_valid_filename(options)
    if options.confirm
      if !gista#util#prompt#asktf(printf(
            \ 'Remove %s of %s in %s? ',
            \ filename, gistid, client.apiname,
            \))
        call gista#util#prompt#throw('Cancel')
      endif
    endif
    call gista#resource#remote#patch(gistid, {
          \ 'force': options.force,
          \ 'filenames': [filename],
          \ 'contents': [{}],
          \})
    call gista#util#doautocmd('CacheUpdatePost')
    call gista#indicate(options, printf(
          \ 'A %s is removed from a gist %s in %s',
          \ filename, gistid, client.apiname,
          \))
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista remove',
          \ 'description': 'Remove a file of a gist',
          \})
    call s:parser.add_argument(
          \ '--force',
          \ 'Delete a file even a remote content of the gist is modified', {
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
    call s:parser.add_argument(
          \ 'filename',
          \ 'A filename', {
          \   'complete': function('g:gista#option#complete_filename'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#remove#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#option#assign_gistid(options, '%')
  call gista#option#assign_filename(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#remove#default_options),
        \ options,
        \)
  call gista#command#remove#call(options)
endfunction
function! gista#command#remove#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#remove', {
      \ 'default_options': {},
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
