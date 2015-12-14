let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:J = s:V.import('Web.JSON')
let s:A = s:V.import('ArgumentParser')

function! s:handle_exception(exception) abort " {{{
  redraw
  let canceled_by_user_patterns = [
        \ '^vim-gista: Login canceled',
        \ '^vim-gista: ValidationError: An API name cannot be empty',
        \ '^vim-gista: ValidationError: An API account username cannot be empty',
        \ '^vim-gista: ValidationError: A gist ID cannot be empty',
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
function! gista#command#json#read(...) abort " {{{
  let options = extend({
        \ 'gistid': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let gist = gista#api#get#get(
          \ options.gistid, options
          \)
    let content = split(
          \ s:J.encode(gist, { 'indent': 2 }),
          \ "\r\\?\n"
          \)
    call gista#util#buffer#read_content(
          \ content,
          \ printf('%s.json', tempname()),
          \)
    call gista#command#list#update_if_necessary()
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction " }}}
function! gista#command#json#edit(...) abort " {{{
  let options = extend({
        \ 'gistid': '',
        \ 'opener': '',
        \}, get(a:000, 0, {})
        \)
  try
    let gist = gista#api#get#get(
          \ options.gistid, options
          \)
    let content = split(
          \ s:J.encode(gist, { 'indent': 2 }),
          \ "\r\\?\n"
          \)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return
  endtry
  let opener = empty(options.opener)
        \ ? g:gista#command#json#default_opener
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
    let bufname = printf('gista:%s:%s.json',
          \ client.apiname, gist.id,
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
        \ printf('%s.json', tempname()),
        \)
  let b:gista = {
        \ 'apiname': apiname,
        \ 'username': username,
        \ 'gistid': gist.id,
        \}
  setlocal buftype=nofile
  setlocal nomodifiable
  setlocal filetype=json
  if is_pedit
    setlocal previewwindow
    silent keepjumps wincmd p
  endif
  call gista#command#list#update_if_necessary()
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista json',
          \ 'description': 'Open a JSON of a particular gist',
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#api#get#complete_gistid'),
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
function! gista#command#json#command(...) abort " {{{
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#json#default_options),
        \ options,
        \)
  call gista#command#json#edit(options)
endfunction " }}}
function! gista#command#json#complete(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction " }}}

call gista#define_variables('command#json', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
