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
function! gista#command#patch#call(...) abort
  let options = extend({
        \ 'gistid': '',
        \ 'cache': 0,
        \}, get(a:000, 0, {}),
        \)
  let filename = fnamemodify(gista#meta#guess_filename('%'), ':t')
  let content  = join(call('getline', options.__range__), "\n")
  let options.filenames = [ filename ]
  let options.contents  = [
        \ { 'content': content },
        \]
  try
    let gistid = gista#meta#get_valid_gistid(options.gistid)
    let gist   = gista#resource#gists#patch(gistid, options)
    let bufname = gista#command#open#bufname({
          \ 'gistid': gist.id,
          \ 'filename': filename,
          \})
    silent execute printf('file %s', bufname)
    call gista#util#doautocmd('CacheUpdatePost')
    redraw
    let client = gista#client#get()
    call gista#util#prompt#echo(printf(
          \ 'Changes of %s in gist %s is posted to %s',
          \ filename, gistid, client.apiname,
          \))
    return gist
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return {}
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista patch',
          \ 'description': 'Patch a current buffer content into an existing gist',
          \})
    call s:parser.add_argument(
          \ '--description', '-d',
          \ 'A description of a gist', {
          \   'type': s:A.types.value,
          \})
    call s:parser.add_argument(
          \ '--force',
          \ 'Patch a gist even a remote content of the gist is modified', {
          \   'default': 0,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#meta#complete_gistid'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#patch#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#meta#assign_gistid(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#patch#default_options),
        \ options,
        \)
  call gista#command#patch#call(options)
endfunction
function! gista#command#patch#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#patch', {
      \ 'default_options': {},
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
