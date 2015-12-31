let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:C = s:V.import('Vim.Compat')
let s:S = s:V.import('Data.String')
let s:D = s:V.import('Data.Dict')
let s:A = s:V.import('ArgumentParser')

let s:PRIVATE_GISTID = repeat('*', 20)
let s:LABEL_MODES = [
      \ 'created_at',
      \ 'updated_at',
      \]

function! s:truncate(str, width) abort
  let suffix = strdisplaywidth(a:str) > a:width ? '...' : '   '
  return s:S.truncate(a:str, a:width - 4) . suffix
endfunction
function! s:format_entry(entry) abort
  let gistid = a:entry.public
        \ ? 'gistid:' . a:entry.id
        \ : 'gistid:' . s:PRIVATE_GISTID
  let fetched  = a:entry._gista_fetched  ? '=' : '-'
  let modified = a:entry._gista_modified ? '*' : ' '
  let label    = s:get_current_label(a:entry)
  let prefix = fetched . ' ' . label . ' ' . modified . ' '
  let suffix = ' ' . gistid
  let width = winwidth(0) - strdisplaywidth(prefix . suffix)
  let description = empty(a:entry.description)
        \ ? join(keys(a:entry.files), ', ')
        \ : a:entry.description
  let description = substitute(description, "[\r\n]", ' ', 'g')
  let description = printf('[%d] %s', len(a:entry.files), description)
  let description = s:truncate(description, width)
  return prefix . description . suffix
endfunction
function! s:get_entry(index, ...) abort
  let offset = get(a:000, 0, 0)
  return get(b:gista.entries, a:index + offset, {})
endfunction

function! s:get_current_label_index() abort
  if !exists('s:current_label_index')
    let index = index(s:LABEL_MODES, g:gista#command#list#default_label)
    if index == -1
      call gista#util#prompt#throw(printf(
            \ 'An invalid label "%s" is specified to g:gista#command#list#default_label',
            \ g:gista#command#list#default_label,
            \))
    endif
    let s:current_label_index = index
  endif
  return s:current_label_index
endfunction
function! s:set_current_label_index(index) abort
  let s:current_label_index = a:index
endfunction
function! s:get_current_label(entry) abort
  let lmode = s:LABEL_MODES[s:get_current_label_index()]
  if lmode ==# 'created_at' || lmode ==# 'updated_at'
    let datetime = a:entry[lmode]
    let label = substitute(
          \ datetime,
          \ '\v\d{2}(\d{2})-(\d{2})-(\d{2})T(\d{2}:\d{2}:\d{2})Z',
          \ '\1/\2/\3(\4)',
          \ ''
          \)
    return label
  endif
endfunction

function! s:define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gista-quit)
        \ :<C-u>q<CR>
  noremap <buffer><silent> <Plug>(gista-redraw)
        \ :call <SID>action('redraw')<CR>
  noremap <buffer><silent> <Plug>(gista-update)
        \ :call <SID>action('update', 1)<CR>
  noremap <buffer><silent> <Plug>(gista-UPDATE)
        \ :call <SID>action('update', 0)<CR>
  noremap <buffer><silent> <Plug>(gista-next-label)
        \ :call <SID>action('next_label')<CR>
  noremap <buffer><silent> <Plug>(gista-prev-label)
        \ :call <SID>action('prev_label')<CR>
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
  noremap <buffer><silent> <Plug>(gista-json)
        \ :call <SID>action('json')<CR>
  noremap <buffer><silent> <Plug>(gista-json-above)
        \ :call <SID>action('json', 'above')<CR>
  noremap <buffer><silent> <Plug>(gista-json-below)
        \ :call <SID>action('json', 'below')<CR>
  noremap <buffer><silent> <Plug>(gista-json-left)
        \ :call <SID>action('json', 'left')<CR>
  noremap <buffer><silent> <Plug>(gista-json-right)
        \ :call <SID>action('json', 'right')<CR>
  noremap <buffer><silent> <Plug>(gista-json-tab)
        \ :call <SID>action('json', 'tab')<CR>
  noremap <buffer><silent> <Plug>(gista-json-preview)
        \ :call <SID>action('json', 'preview')<CR>
  noremap <buffer><silent> <Plug>(gista-browse-open)
        \ :call <SID>action('browse', 'open')<CR>
  noremap <buffer><silent> <Plug>(gista-browse-yank)
        \ :call <SID>action('browse', 'yank')<CR>
  noremap <buffer><silent> <Plug>(gista-browse-echo)
        \ :call <SID>action('browse', 'echo')<CR>
  noremap <buffer><silent> <Plug>(gista-delete)
        \ :call <SID>action('delete', 1)<CR>
  noremap <buffer><silent> <Plug>(gista-DELETE)
        \ :call <SID>action('delete', 0)<CR>
  noremap <buffer><silent> <Plug>(gista-star)
        \ :call <SID>action('star')<CR>
  noremap <buffer><silent> <Plug>(gista-unstar)
        \ :call <SID>action('unstar')<CR>
  noremap <buffer><silent> <Plug>(gista-fork)
        \ :call <SID>action('fork')<CR>
endfunction
function! s:define_default_mappings() abort
  map <buffer> q <Plug>(gista-quit)
  map <buffer> <C-n> <Plug>(gista-next-label)
  map <buffer> <C-p> <Plug>(gista-prev-label)
  map <buffer> <C-l> <Plug>(gista-redraw)
  map <buffer> <F5>   <Plug>(gista-update)
  map <buffer> <S-F5> <Plug>(gista-UPDATE)
  map <buffer> <Return> <Plug>(gista-edit)
  map <buffer> ee <Plug>(gista-edit)
  map <buffer> EE <Plug>(gista-edit-right)
  map <buffer> tt <Plug>(gista-edit-tab)
  map <buffer> pp <Plug>(gista-edit-preview)
  map <buffer> ej <Plug>(gista-json)
  map <buffer> EJ <Plug>(gista-json-right)
  map <buffer> tj <Plug>(gista-json-tab)
  map <buffer> pj <Plug>(gista-json-preview)
  map <buffer> bb <Plug>(gista-browse-open)
  map <buffer> yy <Plug>(gista-browse-yank)
  map <buffer> dd <Plug>(gista-delete)
  map <buffer> DD <Plug>(gista-DELETE)
  map <buffer> ++ <Plug>(gista-star)
  map <buffer> -- <Plug>(gista-unstar)
  map <buffer> FF <Plug>(gista-fork)
endfunction

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
function! gista#command#list#open(...) abort
  let options = extend({
        \ 'lookup': '',
        \ 'opener': '',
        \ 'cache': 1,
        \}, get(a:000, 0, {})
        \)
  try
    let lookup = gista#meta#get_valid_lookup(options.lookup)
    let index  = gista#api#gists#list(lookup, options)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return
  endtry
  let client = gista#api#get_current_client()
  let apiname = client.apiname
  let username = client.get_authorized_username()
  let opener = empty(options.opener)
        \ ? g:gista#command#list#default_opener
        \ : options.opener
  let bufname = printf('gista-list:%s:%s',
        \ client.apiname, lookup,
        \)
  call gista#util#buffer#open(bufname, {
        \ 'opener': opener . (options.cache ? '' : '!'),
        \ 'group': 'manipulation_panel',
        \})
  let b:gista = {
        \ 'winwidth': winwidth(0),
        \ 'apiname': apiname,
        \ 'username': username,
        \ 'lookup': lookup,
        \ 'entries': index.entries,
        \ 'options': s:D.omit(options, ['cache']),
        \ 'content_type': 'list',
        \}
  call s:define_plugin_mappings()
  if g:gista#command#list#enable_default_mappings
    call s:define_default_mappings()
  endif
  augroup vim_gista_list
    autocmd! * <buffer>
    autocmd VimResized <buffer> call s:on_VimResized()
    autocmd WinEnter   <buffer> call s:on_WinEnter()
  augroup END
  setlocal nonumber nolist nowrap nospell nofoldenable textwidth=0
  setlocal foldcolumn=0 colorcolumn=0
  setlocal cursorline
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  setlocal filetype=gista-list
  call gista#command#list#redraw()
endfunction
function! gista#command#list#redraw() abort
  if &filetype !=# 'gista-list'
    call gista#util#prompt#throw(
          \ 'redraw() requires to be called in a gista-list buffer'
          \)
  endif
  redraw
  call gista#util#prompt#echo('Formatting gist entries to display ...')
  call gista#util#buffer#edit_content(
        \ map(copy(b:gista.entries), 's:format_entry(v:val)')
        \)
  redraw
endfunction
function! gista#command#list#update(...) abort
  if &filetype !=# 'gista-list'
    call gista#util#prompt#throw(
          \ 'update() requires to be called in a gista-list buffer'
          \)
  endif
  let options = extend(b:gista.options, get(a:000, 0, {}))
  try
    let lookup = gista#meta#get_valid_lookup(options.lookup)
    let index  = gista#api#gists#list(lookup, options)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return
  endtry
  let client = gista#api#get_current_client()
  let apiname = client.apiname
  let username = client.get_authorized_username()
  let b:gista = {
        \ 'winwidth': winwidth(0),
        \ 'apiname': apiname,
        \ 'username': username,
        \ 'lookup': lookup,
        \ 'entries': index.entries,
        \ 'options': options,
        \ 'content_type': 'list',
        \}
  call gista#command#list#redraw()
endfunction

function! s:on_VimResized() abort
  call gista#util#buffer#edit_content(
        \ map(copy(b:gista.entries), 's:format_entry(v:val)')
        \)
endfunction
function! s:on_WinEnter() abort
  if b:gista.winwidth != winwidth(0)
    call gista#util#buffer#edit_content(
          \ map(copy(b:gista.entries), 's:format_entry(v:val)')
          \)
  endif
endfunction

function! s:action(name, ...) range abort
  let fname = printf('s:action_%s', a:name)
  if !exists('*' . fname)
    throw printf('vim-gista: Unknown action name "%s" is called.', a:name)
  endif
  " Call action function with a:firstline and a:lastline propagation
  execute printf(
        \ '%d,%dcall call("%s", a:000)',
        \ a:firstline, a:lastline, fname
        \)
endfunction
function! s:action_edit(...) range abort
  let opener = get(a:000, 0, '')
  let opener = empty(opener)
        \ ? g:gista#command#list#default_entry_opener
        \ : opener
  let [opener, anchor] = get(
        \ g:gista#command#list#entry_openers,
        \ opener, ['edit', 1],
        \)
  let session = gista#api#session({
        \ 'apiname': b:gista.apiname,
        \ 'username': b:gista.username,
        \})
  try
    call session.enter()
    for n in range(a:firstline, a:lastline)
      let entry = s:get_entry(n - 1)
      if empty(entry)
        continue
      endif
      if anchor
        call gista#util#anchor#focus()
      endif
      call gista#command#open#open({
            \ 'gist': entry,
            \ 'opener': opener,
            \})
    endfor
  finally
    call session.exit()
  endtry
endfunction
function! s:action_json(...) range abort
  let opener = get(a:000, 0, '')
  let opener = empty(opener)
        \ ? g:gista#command#list#default_entry_opener
        \ : opener
  let [opener, anchor] = get(
        \ g:gista#command#list#entry_openers,
        \ opener, ['edit', 1],
        \)
  let session = gista#api#session({
        \ 'apiname': b:gista.apiname,
        \ 'username': b:gista.username,
        \})
  try
    call session.enter()
    for n in range(a:firstline, a:lastline)
      let entry = s:get_entry(n - 1)
      if empty(entry)
        continue
      endif
      if anchor
        call gista#util#anchor#focus()
      endif
      call gista#command#json#open({
            \ 'gistid': entry.id,
            \ 'opener': opener,
            \})
    endfor
  finally
    call session.exit()
  endtry
endfunction
function! s:action_browse(...) range abort
  let action = get(a:000, 0, 'open')
  let session = gista#api#session({
        \ 'apiname': b:gista.apiname,
        \ 'username': b:gista.username,
        \})
  try
    call session.enter()
    for n in range(a:firstline, a:lastline)
      let entry = s:get_entry(n - 1)
      if empty(entry)
        continue
      endif
      call gista#command#browse#{action}({
            \ 'gistid': entry.id,
            \})
    endfor
  finally
    call session.exit()
  endtry
endfunction
function! s:action_delete(...) range abort
  " TODO
  " Show a prompt to ask
  let cache = get(a:000, 0, 1)
  let session = gista#api#session({
        \ 'apiname': b:gista.apiname,
        \ 'username': b:gista.username,
        \})
  try
    call session.enter()
    for n in range(a:firstline, a:lastline)
      let entry = s:get_entry(n - 1)
      if empty(entry)
        continue
      endif
      call gista#command#delete#call({
            \ 'gistid': entry.id,
            \ 'cache': cache,
            \})
    endfor
  finally
    call session.exit()
  endtry
endfunction
function! s:action_star(...) range abort
  let session = gista#api#session({
        \ 'apiname': b:gista.apiname,
        \ 'username': b:gista.username,
        \})
  try
    call session.enter()
    for n in range(a:firstline, a:lastline)
      let entry = s:get_entry(n - 1)
      if empty(entry)
        continue
      endif
      call gista#command#star#call({
            \ 'gistid': entry.id,
            \})
    endfor
  finally
    call session.exit()
  endtry
endfunction
function! s:action_fork(...) range abort
  let session = gista#api#session({
        \ 'apiname': b:gista.apiname,
        \ 'username': b:gista.username,
        \})
  try
    call session.enter()
    for n in range(a:firstline, a:lastline)
      let entry = s:get_entry(n - 1)
      if empty(entry)
        continue
      endif
      call gista#command#fork#call({
            \ 'gistid': entry.id,
            \})
    endfor
  finally
    call session.exit()
  endtry
endfunction
function! s:action_unstar(...) range abort
  let session = gista#api#session({
        \ 'apiname': b:gista.apiname,
        \ 'username': b:gista.username,
        \})
  try
    call session.enter()
    for n in range(a:firstline, a:lastline)
      let entry = s:get_entry(n - 1)
      if empty(entry)
        continue
      endif
      call gista#command#unstar#call({
            \ 'gistid': entry.id,
            \})
    endfor
  finally
    call session.exit()
  endtry
endfunction
function! s:action_redraw(...) range abort
  call gista#command#list#redraw()
endfunction
function! s:action_update(...) range abort
  let cache = get(a:000, 0, 1)
  call gista#command#list#update({ 'cache': cache })
endfunction
function! s:action_next_label(...) range abort
  let index = s:get_current_label_index() + 1
  let index = index >= len(s:LABEL_MODES) ? 0 : index
  call s:set_current_label_index(index)
  call s:action_update()
endfunction
function! s:action_prev_label(...) range abort
  let index = s:get_current_label_index() - 1
  let index = index < 0 ? len(s:LABEL_MODES) - 1 : index
  call s:set_current_label_index(index)
  call s:action_update()
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista[!] list',
          \ 'description': [
          \   'List gists of a paricular lookup.',
          \   'A bang (!) is a short form of "--no-cache --no-since".',
          \ ],
          \})
    call s:parser.add_argument(
          \ 'lookup',
          \ 'Gists lookup', {
          \   'complete': function('gista#meta#complete_lookup'), 
          \})
    call s:parser.add_argument(
          \ '--cache',
          \ 'Use cached entries whenever possible', {
          \   'default': 1,
          \   'deniable': 1,
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
    if has('python') || has('python3')
      call s:parser.add_argument(
            \ '--python', [
            \   'Use python to request gists (Default)',
            \ ], {
            \   'deniable': 1,
            \ })
    endif
  endif
  return s:parser
endfunction
function! gista#command#list#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#list#default_options),
        \ options,
        \)
  if options.__bang__
    let options.cache = 0
    let options.since = ''
  endif
  call gista#command#list#open(options)
endfunction
function! gista#command#list#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

function! gista#command#list#define_highlights() abort
  " TODO: Add 'default' keyword when development has reached stable phase
  " e.g. highlight default link GistaPartialMarker    Constant
  highlight link GistaPartialMarker    Comment
  highlight link GistaDownloadedMarker Special
  highlight link GistaModifiedMarker   WarningMsg
  highlight link GistaLastModified     Comment
  highlight link GistaGistIDPublic     Tag
  highlight link GistaGistIDPrivate    Constant
endfunction
function! gista#command#list#define_syntax() abort
  syntax match GistaLine /^[=\-].*gistid:.\{,20}\%(\/[a-zA-Z0-9]\+\)\?$/
  syntax match GistaGistIDPublic /gistid:[a-zA-Z0-9_\-]\{,20}\%(\/[a-zA-Z0-9]\+\)\?$/
        \ display contained containedin=GistaLine
  syntax match GistaGistIDPrivate /gistid:\*\{20}$/
        \ display contained containedin=GistaLine
  syntax match GistaMeta /^[=\-] \d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2}:\d\{2}) [ \*]/
        \ display contained containedin=GistaLine
  syntax match GistaPartialMarker /^-/
        \ display contained containedin=GistaMeta
  syntax match GistaDownloadedMarker /^=/
        \ display contained containedin=GistaMeta
  syntax match GistaLastModified /\d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2}:\d\{2})/
        \ display contained containedin=GistaMeta
  syntax match GistaModifiedMarker /[ \*]/
        \ display contained containedin=GistaMeta
endfunction

function! gista#command#list#get_status_string(...) abort
  let lookup = get(a:000, 0, '')
  if empty(lookup)
    return printf('gista | %s:%s | Mode: %s',
          \ b:gista.apiname,
          \ b:gista.lookup,
          \ s:LABEL_MODES[s:get_current_label_index()]
          \)
  endif
endfunction

augroup vim_gista_update_list
  autocmd!
  autocmd User GistaCacheUpdatePost windo
        \ if &filetype ==# 'gista-list' |
        \   call s:action_update(1) |
        \ endif
augroup END

call gista#define_variables('command#list', {
      \ 'default_options': {},
      \ 'default_lookup': '',
      \ 'default_label': 'updated_at',
      \ 'default_datetime': 'updated_at',
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
      \ 'enable_default_mappings': 1,
      \})

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
