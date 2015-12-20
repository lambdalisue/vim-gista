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
function! gista#command#open#read(...) abort " {{{
  let options = extend({
        \ 'gistid': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let gist = gista#api#gists#get(
          \ options.gistid, options
          \)
    let content = gista#api#gists#get_content(
          \ gist, options.filename, options,
          \)
    call gista#util#buffer#read_content(
          \ content.content,
          \ printf('%s.%s', tempname(), fnamemodify(content.filename, ':e')),
          \)
    call gista#command#list#update_if_necessary()
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction " }}}
function! gista#command#open#edit(...) abort " {{{
  let options = extend({
        \ 'gistid': '',
        \ 'filename': '',
        \ 'opener': '',
        \}, get(a:000, 0, {})
        \)
  try
    let gist = gista#api#gists#get(
          \ options.gistid, options
          \)
    let content = gista#api#gists#get_content(
          \ gist, options.filename, options,
          \)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return
  endtry
  let opener = empty(options.opener)
        \ ? g:gista#command#open#default_opener
        \ : options.opener
  let is_pedit = opener =~# 'pedit'
  let opener = substitute(
        \ opener,
        \ 'pedit',
        \ printf('keepjumps topleft %d split', &previewheight),
        \ '',
        \)
  let client = gista#api#get_current_client()
  let apiname = client.apiname
  let username = client.get_authorized_username()
  if opener !=# 'inplace'
    let bufname = printf('gista:%s:%s:%s',
          \ client.apiname, gist.id, content.filename,
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
        \ content.content,
        \ printf('%s.%s', tempname(), fnamemodify(content.filename, ':e')),
        \)
  let b:gista = {
        \ 'apiname': apiname,
        \ 'username': username,
        \ 'gistid': gist.id,
        \ 'filename': content.filename,
        \}
  if get(get(gist, 'owner', {}), 'login', '') ==# username
    augroup vim_gista_write_file
      autocmd! * <buffer>
      autocmd BufWriteCmd <buffer> call gista#autocmd#call('BufWriteCmd')
      autocmd FileWriteCmd <buffer> call gista#autocmd#call('FileWriteCmd')
    augroup END
    setlocal buftype=acwrite
    setlocal modifiable
  else
    augroup vim_gista_write_file
      autocmd! * <buffer>
    augroup END
    setlocal buftype=nofile
    setlocal nomodifiable
  endif
  filetype detect
  if is_pedit
    setlocal previewwindow
    silent keepjumps wincmd p
  endif
  call gista#command#list#update_if_necessary()
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista open',
          \ 'description': 'Open a content of a particular gist',
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#api#gists#complete_gistid'),
          \   'type': s:A.types.value,
          \})
    call s:parser.add_argument(
          \ 'filename',
          \ 'A filename', {
          \   'complete': function('g:gista#api#gists#complete_filename'),
          \   'type': s:A.types.value,
          \})
    call s:parser.add_argument(
          \ '--opener',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:A.types.value,
          \})
  endif
  return s:parser
endfunction " }}}
function! gista#command#open#command(...) abort " {{{
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#open#default_options),
        \ options,
        \)
  call gista#command#read#edit(options)
endfunction " }}}
function! gista#command#open#complete(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction " }}}

call gista#define_variables('command#open', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
