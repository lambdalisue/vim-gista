let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! s:handle_exception(exception) abort " {{{
  redraw
  let canceled_by_user_patterns = [
        \ '^vim-gista: Login canceled',
        \ '^vim-gista: ValidationError: An API name cannot be empty',
        \ '^vim-gista: ValidationError: An API account username cannot be empty',
        \ '^vim-gista: ValidationError: A gist ID cannot be empty',
        \ '^vim-gista: ValidationError: A filename cannot be empty',
        \]
  for pattern in canceled_by_user_patterns
    if a:exception =~# pattern
      call gista#util#prompt#warn('Canceled')
      return
    endif
  endfor
  " else
  call gista#util#prompt#error(a:exception)
endfunction " }}}
function! gista#command#read#read(...) abort " {{{
  let options = get(a:000, 0, {})
  try
    let content = gista#api#call_read(options)
    let filename = gista#api#read#get_current_filename()
    call gista#util#buffer#read_content(
          \ content,
          \ printf('%s.%s', tempname(), fnamemodify(filename, ':e')),
          \)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction " }}}
function! gista#command#read#edit(...) abort " {{{
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {})
        \)
  try
    let content = gista#api#call_read(options)
    let apiname = gista#api#get_current_apiname()
    let username = gista#api#get_current_username()
    let anonymous = gista#api#get_current_anonymous()
    let gistid = gista#api#get#get_current_gistid()
    let filename = gista#api#read#get_current_filename()
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return
  endtry
  let opener = empty(options.opener)
        \ ? g:gista#command#read#default_opener
        \ : options.opener
  if opener !=# 'inplace'
    let bufname = printf('gista:%s:%s:%s',
          \ apiname, gistid, filename,
          \)
    try
      let saved_eventignore = &eventignore
      set eventignore=BufReadCmd
      call gista#util#buffer#open(bufname, {
            \ 'opener': opener,
            \})
    finally
      let &eventignore = saved_eventignore
    endtry
  endif
  call gista#util#buffer#edit_content(
        \ content,
        \ printf('%s.%s', tempname(), fnamemodify(filename, ':e')),
        \)
  let b:gista = {
        \ 'apiname': apiname,
        \ 'username': username,
        \ 'anonymous': anonymous,
        \ 'gistid': gistid,
        \}
  augroup vim_gista_write_file
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call gista#autocmd#call('BufWriteCmd')
    autocmd FileWriteCmd <buffer> call gista#autocmd#call('FileWriteCmd')
  augroup END
  setlocal buftype=acwrite
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:A.new({
          \ 'name': 'Gista get',
          \ 'description': 'Get and open a file in a gist',
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#api#complete_gistid'),
          \})
    call s:parser.add_argument(
          \ 'filename',
          \ 'A filename', {
          \   'complete': function('g:gista#api#complete_filename'),
          \})
    call s:parser.add_argument(
          \ '--apiname',
          \ 'An API name', {
          \   'type': s:A.types.value,
          \   'complete': function('g:gista#api#complete_apiname'),
          \})
    call s:parser.add_argument(
          \ '--username',
          \ 'A username of an API account.', {
          \   'type': s:A.types.value,
          \   'complete': function('g:gista#api#complete_username'),
          \})
    call s:parser.add_argument(
          \ '--anonymous',
          \ 'Request gists as an anonymous user', {
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ '--opener',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:A.types.value,
          \})
  endif
  return s:parser
endfunction " }}}
function! gista#command#read#command(bang, range, ...) abort " {{{
  let options = s:get_parser().parse(a:bang, a:range, get(a:000, 0, ''))
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#read#default_options),
        \ options,
        \)
  call gista#command#read#edit(options)
endfunction " }}}
function! gista#command#read#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:get_parser().complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

call gista#define_variables('command#read', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
