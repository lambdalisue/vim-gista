let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:J = s:V.import('Web.JSON')
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
function! gista#command#json#read(...) abort
  silent doautocmd FileReadPre
  let options = extend({
        \ 'gistid': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let gistid = gista#meta#get_valid_gistid(options.gistid)
    let gist = gista#resource#gists#get(gistid, options)
    let content = split(
          \ s:J.encode(gist, { 'indent': 2 }),
          \ "\r\\?\n"
          \)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
  call gista#util#buffer#read_content(
        \ content,
        \ printf('%s.json', tempname()),
        \)
  silent doautocmd FileReadPost
  call gista#util#doautocmd('CacheUpdatePost')
endfunction
function! gista#command#json#edit(...) abort
  silent doautocmd BufReadPre
  let options = extend({
        \ 'gistid': '',
        \}, get(a:000, 0, {})
        \)
  try
    let gistid = gista#meta#get_valid_gistid(options.gistid)
    let gist = gista#resource#gists#get(gistid, options)
    let content = split(
          \ s:J.encode(gist, { 'indent': 2 }),
          \ "\r\\?\n"
          \)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return
  endtry
  let client = gista#client#get()
  let apiname = client.apiname
  let username = client.get_authorized_username()
  let b:gista = {
        \ 'apiname': apiname,
        \ 'username': username,
        \ 'gistid': gistid,
        \ 'content_type': 'json',
        \}
  call gista#util#buffer#edit_content(
        \ content,
        \ printf('%s.json', tempname()),
        \)
  setlocal buftype=nowrite
  setlocal nomodifiable
  setlocal filetype=json
  silent doautocmd BufReadPost
  call gista#util#doautocmd('CacheUpdatePost')
endfunction
function! gista#command#json#open(...) abort
  let options = extend({
        \ 'opener': '',
        \ 'cache': 1,
        \}, get(a:000, 0, {})
        \)
  let opener = empty(options.opener)
        \ ? g:gista#command#json#default_opener
        \ : options.opener
  let bufname = gista#command#json#bufname(options)
  if !empty(bufname)
    call gista#util#buffer#open(bufname, {
          \ 'opener': opener . (options.cache ? '' : '!'),
          \})
    " BufReadCmd will execute gista#command#json#edit()
  endif
endfunction
function! gista#command#json#bufname(...) abort
  let options = extend({
        \ 'gistid': '',
        \ 'cache': 1,
        \}, get(a:000, 0, {})
        \)
  try
    let gistid = gista#meta#get_valid_gistid(options.gistid)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return
  endtry
  let client = gista#client#get()
  let apiname = client.apiname
  return printf('gista-json:%s:%s',
        \ client.apiname, gistid,
        \)
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista json',
          \ 'description': 'Open a JSON of a particular gist',
          \})
    call s:parser.add_argument(
          \ '--opener',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:A.types.value,
          \})
    call s:parser.add_argument(
          \ '--cache',
          \ 'Use cached content whenever possible.', {
          \   'default': 1,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#meta#complete_gistid'),
          \   'type': s:A.types.value,
          \})
  endif
  return s:parser
endfunction
function! gista#command#json#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#meta#assign_gistid(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#json#default_options),
        \ options,
        \)
  call gista#command#json#open(options)
endfunction
function! gista#command#json#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#json', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
