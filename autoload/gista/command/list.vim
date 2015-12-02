let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:S = s:V.import('Data.String')
let s:A = s:V.import('ArgumentParser')

function! s:handle_exception(exception) abort " {{{
  redraw
  let canceled_by_user_patterns = [
        \ '^vim-gista: Login canceled',
        \ '^vim-gista: ValidationError: An API name cannot be empty',
        \ '^vim-gista: ValidationError: An API account username cannot be empty',
        \ '^vim-gista: ValidationError: A lookup cannot be empty',
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
function! s:format_entry(apiname, entry) abort " {{{
  let gistid = a:entry.public
        \ ? printf('gistid:%s', a:entry.id)
        \ : printf('gistid:%s', repeat('*', 20))
  let description = empty(a:entry.description)
        \ ? join(keys(a:entry.files), ', ')
        \ : a:entry.description
  let partial  = get(a:entry, '_gista_partial', 1) ? '-' : '='
  let modified = get(a:entry, '_gista_modified', 0) ? '*' : ' '
  let updated_at = substitute(
        \ a:entry.updated_at,
        \ '\v\d{2}(\d{2})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):\d{2}Z',
        \ '\1/\2/\3(\4:\5)',
        \ ''
        \)
  let const = join([updated_at, gistid, partial, modified], ' ')
  let width = winwidth(0) - len(const) - 3
  return [
        \ printf(
        \   '%s %s %s %s   %s',
        \   partial,
        \   updated_at,
        \   modified,
        \   s:S.truncate_skipping(description, width, 3, '...'),
        \   gistid,
        \ )
        \]
endfunction " }}}
function! s:parse_entry(entry) abort " {{{
  let m = matchlist(a:entry, 'gistid:\(.*\)$')
  if len(m)
    return { 'gistid': m[1] }
  else
    return {}
  endif
endfunction " }}}
function! s:define_plug_mappings() abort " {{{
  noremap <buffer><silent> <Plug>(gista-quit)
        \ :<C-u>q<CR>
  noremap <buffer><silent> <Plug>(gista-update)
        \ :call <SID>action('update')<CR>
  noremap <buffer><silent> <Plug>(gista-UPDATE)
        \ :call <SID>action('update', 1)<CR>
  noremap <buffer><silent> <Plug>(gista-edit)
        \ :call <SID>action('edit')<CR>
  noremap <buffer><silent> <Plug>(gista-edit-above)
        \ :call <SID>action('edit', 'above')<CR>
  noremap <buffer><silent> <Plug>(gista-edit-below)
        \ :call <SID>action('edit', 'below')<CR>
  noremap <buffer><silent> <Plug>(gista-edit-left)
        \ :call <SID>action('edit', 'left')<CR>
  noremap <buffer><silent> <Plug>(gista-edit-right)
        \ :call <SID>action('edit', 'right')<CR>
  noremap <buffer><silent> <Plug>(gista-edit-tab)
        \ :call <SID>action('edit', 'tab')<CR>
  noremap <buffer><silent> <Plug>(gista-edit-preview)
        \ :call <SID>action('edit', 'preview')<CR>
endfunction " }}}
function! s:define_default_mappings() abort " {{{
  map <buffer> <C-l> <Plug>(gista-update)
  map <buffer> q <Plug>(gista-quit)
  map <buffer> <Return> <Plug>(gista-edit)
  map <buffer> ee <Plug>(gista-edit)
  map <buffer> EE <Plug>(gista-edit-right)
  map <buffer> et <Plug>(gista-edit-tab)
  map <buffer> ep <Plug>(gista-edit-preview)
endfunction " }}}
function! s:on_VimResized() abort " {{{
  call s:action_update()
endfunction " }}}
function! s:on_WinEnter() abort " {{{
  if b:gista.winwidth != winwidth(0)
    call s:action_update()
  endif
endfunction " }}}
function! gista#command#list#call(...) abort " {{{
  let options = get(a:000, 0, {})
  try
    let entries = gista#api#call_list(options)
    return entries
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return []
  endtry
endfunction " }}}
function! gista#command#list#open(...) abort " {{{
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {})
        \)
  try
    let entries = gista#api#call_list(options)
    let apiname = gista#api#get_current_apiname()
    let username = gista#api#get_current_username()
    let anonymous = gista#api#get_current_anonymous()
    let lookup  = gista#api#list#get_current_lookup()
    if !len(entries)
      call gista#util#prompt#warn(printf(
            \ 'No gist entries are exists for a lookup "%s" on "%s".',
            \ lookup, apiname,
            \))
      return
    endif
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return
  endtry
  " Open a list window
  let opener = empty(options.opener)
        \ ? g:gista#command#list#default_opener
        \ : options.opener
  let bufname = printf('gista-list:%s:%s', apiname, lookup)
  let ret = gista#util#buffer#open(bufname, {
        \ 'group': 'manipulation_panel',
        \ 'opener': opener,
        \})
  " Create a list window content and apply
  let content = []
  for entry in entries
    call extend(content, s:format_entry(apiname, entry))
  endfor
  call gista#util#buffer#edit_content(content)
  call s:define_plug_mappings()
  call s:define_default_mappings()
  augroup vim_gista_list
    autocmd! * <buffer>
    autocmd VimResized <buffer> call s:on_VimResized()
    autocmd WinEnter <buffer> call s:on_WinEnter()
  augroup END
  setlocal nonumber nolist nowrap nospell nofoldenable textwidth=0
  setlocal foldcolumn=0 colorcolumn=0
  setlocal cursorline
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  setlocal isfname& isfname+=:
  setlocal filetype=gista-list
  let b:gista = {
        \ 'winwidth': winwidth(0),
        \ 'apiname': apiname,
        \ 'username': username,
        \ 'anonymous': anonymous,
        \ 'lookup': lookup,
        \}
endfunction " }}}
function! gista#command#list#update_if_necessary(...) abort " {{{
  let fresh = get(a:000, 0)
  let saved_winnum = winnr()
  for winnum in range(1, winnr('$'))
    if gista#util#compat#getbufvar(winbufnr(winnum), '&filetype') ==# 'gista-list'
      silent execute printf('keepjump %dwincmd w', winnum)
      call s:action_update(fresh)
      silent execute printf('keepjump %dwincmd w', saved_winnum)
      return
    endif
  endfor
endfunction " }}}

function! s:action(name, ...) range abort " {{{
  let fname = printf('s:action_%s', a:name)
  if !exists('*' . fname)
    throw printf('vim-gista: Unknown action name "%s" is called.', a:name)
  endif
  " Call action function with a:firstline and a:lastline propagation
  execute printf(
        \ '%d,%dcall call("%s", a:000)',
        \ a:firstline, a:lastline, fname
        \)
endfunction " }}}
function! s:action_edit(...) range abort " {{{
  let gista = b:gista
  let opener = get(a:000, 0, '')
  let opener = empty(opener)
        \ ? g:gista#command#list#default_entry_opener
        \ : opener
  let [opener, anchor] = get(
        \ g:gista#command#list#entry_openers, opener, ['edit', 1],
        \)
  for n in range(a:firstline, a:lastline)
    let meta = s:parse_entry(getline(n))
    if empty(meta)
      continue
    endif
    if anchor
      call gista#util#anchor#focus()
    endif
    call gista#command#read#edit({
          \ 'apiname': gista.apiname,
          \ 'username': gista.username,
          \ 'anonymous': gista.anonymous,
          \ 'gistid': meta.gistid,
          \ 'opener': opener,
          \})
  endfor
  call gista#command#list#update_if_necessary()
endfunction " }}}
function! s:action_update(...) range abort " {{{
  let gista = b:gista
  let fresh = get(a:000, 0)
  let saved_curpos = gista#util#compat#getcurpos()
  call gista#command#list#open({
        \ 'apiname': gista.apiname,
        \ 'username': gista.username,
        \ 'anonymous': gista.anonymous,
        \ 'lookup': gista.lookup,
        \ 'fresh': fresh,
        \})
  call setpos('.', saved_curpos)
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:A.new({
          \ 'name': 'Gista list',
          \ 'description': 'List or fetch gists of a particular lookup',
          \})
    call s:parser.add_argument(
          \ 'lookup',
          \ 'Request gists of a particular lookup', {
          \   'complete': function('gista#api#complete_lookup'), 
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
          \ '--page',
          \ 'Request gists in a particular page', {
          \   'pattern': '\d\+',
          \})
    call s:parser.add_argument(
          \ '--since', [
          \   'Request gists created/updated later than a paricular timestamp',
          \   'in ISO 8601 format:YYYY-MM-DDTHH:MM:SSZ',
          \ ], {
          \   'type': s:A.types.any,
          \   'deniable': 1,
          \   'pattern': '\%(\|\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\%(Z\|\[+-]\d{4}\)\)',
          \ })
    call s:parser.add_argument(
          \ '--recursive',
          \ 'Requests gists in the next page recursively', {
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ '--fresh',
          \ 'Check if there are any new gists in API',
          \)
  endif
  return s:parser
endfunction " }}}
function! gista#command#list#command(bang, range, ...) abort " {{{
  let options = s:get_parser().parse(a:bang, a:range, get(a:000, 0, ''))
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#list#default_options),
        \ options,
        \)
  call gista#command#list#open(options)
endfunction " }}}
function! gista#command#list#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:get_parser().complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

function! gista#command#list#define_highlights() abort " {{{
  " TODO: Add 'default' keyword when development has reached stable phase
  " e.g. highlight default link GistaPartialMarker    Constant
  highlight link GistaPartialMarker    Comment
  highlight link GistaDownloadedMarker Special
  highlight link GistaModifiedMarker   WarningMsg
  highlight link GistaLastModified     Comment
  highlight link GistaGistIDPublic     Tag
  highlight link GistaGistIDPrivate    Constant
endfunction " }}}
function! gista#command#list#define_syntax() abort " {{{
  syntax match GistaLine /^[=\-].*gistid:.\{,20}$/
  syntax match GistaGistIDPublic /gistid:[a-zA-Z0-9_\-]\{,20}$/
        \ display contained containedin=GistaLine
  syntax match GistaGistIDPrivate /gistid:\*\{20}$/
        \ display contained containedin=GistaLine
  syntax match GistaMeta /^[=\-] \d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2}) [ \*]/
        \ display contained containedin=GistaLine
  syntax match GistaPartialMarker /^-/
        \ display contained containedin=GistaMeta
  syntax match GistaDownloadedMarker /^=/
        \ display contained containedin=GistaMeta
  syntax match GistaLastModified /\d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2})/
        \ display contained containedin=GistaMeta
  syntax match GistaModifiedMarker /[ \*]/
        \ display contained containedin=GistaMeta
endfunction " }}}

call gista#define_variables('command#list', {
      \ 'default_options': {},
      \ 'default_opener': 'topleft 15 split',
      \ 'default_entry_opener': 'edit',
      \ 'entry_openers': {
      \   'edit':    ['edit', 1],
      \   'above':   ['leftabove new', 1],
      \   'below':   ['rightbelow new', 1],
      \   'left':    ['leftabove vnew', 1],
      \   'right':   ['rightbelow vnew', 1],
      \   'tab':     ['tabnew', 0],
      \   'preview': ['pedit', 0],
      \ },
      \})

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
