let s:V = gista#vital()
let s:String = s:V.import('Data.String')
let s:Dict = s:V.import('Data.Dict')
let s:List = s:V.import('Data.List')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')

let s:PRIVATE_GISTID = repeat('*', 32)
let s:MODES = [
      \ 'created_at',
      \ 'updated_at',
      \]
let s:MAPPING_TABLE = {
      \ '<Plug>(gista-quit)': 'Close the buffer',
      \ '<Plug>(gista-redraw)': 'Redraw the buffer',
      \ '<Plug>(gista-update)': 'Update the buffer content',
      \ '<Plug>(gista-toggle-mapping-visibility)': 'Toggle mapping visibility',
      \ '<Plug>(gista-edit)': 'Open a selected gist',
      \ '<Plug>(gista-edit-above)': 'Open a selected gist in an above window',
      \ '<Plug>(gista-edit-below)': 'Open a selected gist in a below window',
      \ '<Plug>(gista-edit-left)': 'Open a selected gist in a left window',
      \ '<Plug>(gista-edit-right)': 'Open a selected gist in a right window',
      \ '<Plug>(gista-edit-tab)': 'Open a selected gist in a next tab',
      \ '<Plug>(gista-edit-preview)': 'Open a selected gist in a preview window',
      \ '<Plug>(gista-json)': 'Open a selected gist as a json file',
      \ '<Plug>(gista-json-above)': 'Open a selected gist as a json file in an above window',
      \ '<Plug>(gista-json-below)': 'Open a selected gist as a json file in a below window',
      \ '<Plug>(gista-json-left)': 'Open a selected gist as a json file in a left window',
      \ '<Plug>(gista-json-right)': 'Open a selected gist as a json file in a right window',
      \ '<Plug>(gista-json-tab)': 'Open a selected gist as a json file in a next tab',
      \ '<Plug>(gista-json-preview)': 'Open a selected gist as a json file in a preview window',
      \ '<Plug>(gista-browse-open)': 'Browse a URL of a selected gist in a system browser',
      \ '<Plug>(gista-browse-yank)': 'Yank a URL of a selected gist',
      \ '<Plug>(gista-browse-echo)': 'Echo a URL of a selected gist',
      \}
let s:entry_offset = 0

function! s:truncate(str, width) abort
  let suffix = strdisplaywidth(a:str) > a:width ? '...' : '   '
  return s:String.truncate(a:str, a:width - 4) . suffix
endfunction
function! s:format_entry(entry) abort
  let fetched = a:entry._gista_fetched ? '=' : '-'
  let datetime = substitute(
        \ a:entry.committed_at,
        \ '\v\d{2}(\d{2})-(\d{2})-(\d{2})T(\d{2}:\d{2}:\d{2})Z',
        \ '\1/\2/\3(\4)',
        \ ''
        \)
  let prefix = fetched . ' ' . datetime . ' '
  let suffix = ' ' . a:entry.version
  let width = winwidth(0) - strdisplaywidth(prefix . suffix)
  if get(a:entry.change_status, 'total', 0)
    let change_status = join([
          \ printf('%d additions', a:entry.change_status.additions),
          \ printf('%d deletions', a:entry.change_status.deletions),
          \], ', ')
  else
    let change_status = 'No changes'
  endif
  return prefix . s:truncate(change_status, width) . suffix
endfunction
function! s:get_entry(index) abort
  let index = a:index - s:entry_offset
  return index >= 0 ? get(b:gista.entries, index, {}) : {}
endfunction

function! s:get_current_mapping_visibility() abort
  if exists('s:current_mapping_visibility')
    return s:current_mapping_visibility
  endif
  let s:current_mapping_visibility =
        \ g:gista#command#commits#default_mapping_visibility
  return s:current_mapping_visibility
endfunction
function! s:set_current_mapping_visibility(value) abort
  let s:current_mapping_visibility = a:value
endfunction

function! s:define_plugin_mappings() abort
  nnoremap <buffer><silent> <Plug>(gista-quit)
        \ :<C-u>q<CR>
  nnoremap <buffer><silent> <Plug>(gista-redraw)
        \ :call <SID>action('redraw')<CR>
  nnoremap <buffer><silent> <Plug>(gista-update)
        \ :call <SID>action('update')<CR>
  nnoremap <buffer><silent> <Plug>(gista-toggle-mapping-visibility)
        \ :call <SID>action('toggle_mapping_visibility')<CR>
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
endfunction
function! s:define_default_mappings() abort
  nmap <buffer> q <Plug>(gista-quit)
  nmap <buffer> ? <Plug>(gista-toggle-mapping-visibility)
  nmap <buffer> <C-l> <Plug>(gista-redraw)
  nmap <buffer> <F5>   <Plug>(gista-redraw)
  nmap <buffer> <S-F5> <Plug>(gista-update)
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
endfunction

function! gista#command#commits#call(...) abort
  let options = extend({
        \ 'gist': {},
        \ 'gistid': '',
        \}, get(a:000, 0, {}))
  try
    let gistid = gista#resource#local#get_valid_gistid(empty(options.gist)
          \ ? options.gistid
          \ : options.gist.id
          \)
    let commits = gista#resource#remote#commits(gistid, options)
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return {}
  endtry
  " Convert commits to entries
  let entries = []
  for commit in commits
    let entry = gista#resource#local#get(gistid . '/' . commit.version)
    let entry = extend(entry, {
          \ 'version': commit.version,
          \ 'committed_at': commit.committed_at,
          \ 'change_status': commit.change_status,
          \})
    call add(entries, entry)
  endfor
  let result = {
        \ 'gistid': gistid,
        \ 'entries': entries,
        \ 'commits': commits,
        \}
  return result
endfunction
function! gista#command#commits#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let result = gista#command#commits#call(options)
  if empty(result)
    return
  endif
  let client = gista#client#get()
  let apiname = client.apiname
  let username = client.get_authorized_username()
  let opener = empty(options.opener)
        \ ? g:gista#command#commits#default_opener
        \ : options.opener
  let bufname = printf('gista-commits:%s:%s',
        \ client.apiname, result.gistid,
        \)
  call gista#util#buffer#open(bufname, {
        \ 'opener': opener . '!',
        \ 'group': 'manipulation_panel',
        \})
  let b:gista = {
        \ 'winwidth': winwidth(0),
        \ 'apiname': apiname,
        \ 'username': username,
        \ 'gistid': result.gistid,
        \ 'entries': result.entries,
        \ 'options': options,
        \ 'content_type': 'commits',
        \}
  call s:define_plugin_mappings()
  if g:gista#command#commits#enable_default_mappings
    call s:define_default_mappings()
  endif
  augroup vim_gista_commits
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> call gista#command#commits#open(b:gista.options)
    autocmd VimResized <buffer> call s:on_VimResized()
    autocmd WinEnter   <buffer> call s:on_WinEnter()
  augroup END
  setlocal nonumber nolist nowrap nospell nofoldenable textwidth=0
  setlocal foldcolumn=0 colorcolumn=0
  setlocal cursorline
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  setlocal filetype=gista-commits
  call gista#command#commits#redraw()
  silent call gista#util#doautocmd('Commits', result)
endfunction
function! gista#command#commits#update(...) abort
  if &filetype !=# 'gista-commits'
    call gista#throw(
          \ 'update() requires to be called in a gista-commits buffer'
          \)
  endif
  let options = extend(copy(b:gista.options), get(a:000, 0, {}))
  let options = extend(options, {
        \ 'gistid': b:gista.gistid,
        \})
  let result = gista#command#commits#call(options)
  if empty(result)
    return
  endif
  let client = gista#client#get()
  let apiname = client.apiname
  let username = client.get_authorized_username()
  let b:gista = {
        \ 'winwidth': winwidth(0),
        \ 'apiname': apiname,
        \ 'username': username,
        \ 'gistid': result.gistid,
        \ 'entries': result.entries,
        \ 'options': options,
        \ 'content_type': 'commits',
        \}
  call gista#command#commits#redraw()
  silent call gista#util#doautocmd('CommitsUpdate', result)
endfunction
function! gista#command#commits#redraw() abort
  if &filetype !=# 'gista-commits'
    call gista#throw(
          \ 'redraw() requires to be called in a gista-commits buffer'
          \)
  endif
  let prologue = s:List.flatten([
        \ g:gista#command#commits#show_status_string_in_prologue
        \   ? [gista#command#commits#get_status_string() . ' | Press ? to toggle a mapping help']
        \   : [],
        \ s:get_current_mapping_visibility()
        \   ? map(gista#util#mapping#help(s:MAPPING_TABLE), '"| " . v:val')
        \   : []
        \])
  redraw
  echo 'Formatting commits to display ...'
  let contents = map(
        \ copy(b:gista.entries),
        \ 's:format_entry(v:val)'
        \)
  let s:entry_offset = len(prologue)
  call gista#util#buffer#edit_content(extend(prologue, contents))
  redraw | echo
endfunction

function! s:on_VimResized() abort
  call gista#command#commits#redraw()
endfunction
function! s:on_WinEnter() abort
  if b:gista.winwidth != winwidth(0)
    call gista#command#commits#redraw()
  endif
endfunction
function! s:on_GistaUpdate() abort
  let winnum = winnr()
  keepjump windo
        \ if &filetype ==# 'gista-commits' |
        \   call s:action_update(0, 0, 1) |
        \ endif
  execute printf('keepjump %dwincmd w', winnum)
endfunction

function! s:action(name, ...) range abort
  let fname = printf('s:action_%s', a:name)
  if !exists('*' . fname)
    call gista#throw(printf(
          \ 'Unknown action name "%s" is called.',
          \ a:name,
          \))
  endif
  " Call action function with a:firstline and a:lastline propagation
  call call(fname, extend([a:firstline, a:lastline], a:000))
endfunction
function! s:action_edit(startline, endline, ...) abort
  let opener = get(a:000, 0, '')
  let opener = empty(opener)
        \ ? g:gista#command#commits#default_entry_opener
        \ : opener
  let [opener, anchor] = get(
        \ g:gista#command#commits#entry_openers,
        \ opener, ['edit', 1],
        \)
  let session = gista#client#session({
        \ 'apiname': b:gista.apiname,
        \ 'username': b:gista.username,
        \})
  try
    if session.enter()
      let entries = []
      for n in range(a:startline, a:endline)
        call add(entries, s:get_entry(n - 1))
      endfor
      call filter(entries, '!empty(v:val)')
      if !empty(entries) && anchor
        call s:Anchor.focus()
      endif
      for entry in entries
        call gista#command#open#open({
              \ 'gist': entry,
              \ 'opener': opener,
              \})
      endfor
    endif
  finally
    call session.exit()
  endtry
endfunction
function! s:action_json(startline, endline, ...) abort
  let opener = get(a:000, 0, '')
  let opener = empty(opener)
        \ ? g:gista#command#commits#default_entry_opener
        \ : opener
  let [opener, anchor] = get(
        \ g:gista#command#commits#entry_openers,
        \ opener, ['edit', 1],
        \)
  let session = gista#client#session({
        \ 'apiname': b:gista.apiname,
        \ 'username': b:gista.username,
        \})
  try
    if session.enter()
      let entries = []
      for n in range(a:startline, a:endline)
        call add(entries, s:get_entry(n - 1))
      endfor
      call filter(entries, '!empty(v:val)')
      if !empty(entries) && anchor
        call s:Anchor.focus()
      endif
      for entry in entries
        call gista#command#json#open({
              \ 'gist': entry,
              \ 'opener': opener,
              \})
      endfor
    endif
  finally
    call session.exit()
  endtry
endfunction
function! s:action_browse(startline, endline, ...) abort
  let action = get(a:000, 0, 'open')
  let session = gista#client#session({
        \ 'apiname': b:gista.apiname,
        \ 'username': b:gista.username,
        \})
  try
    if session.enter()
      let entries = []
      for n in range(a:startline, a:endline)
        call add(entries, s:get_entry(n - 1))
      endfor
      call filter(entries, '!empty(v:val)')
      for entry in entries
        call gista#command#browse#{action}({
              \ 'gist': entry,
              \})
      endfor
    endif
  finally
    call session.exit()
  endtry
endfunction
function! s:action_redraw(startline, endline, ...) abort
  call gista#command#commits#redraw()
endfunction
function! s:action_update(startline, endline, ...) abort
  call gista#command#commits#update()
endfunction
function! s:action_toggle_mapping_visibility(startline, endline, ...) abort
  call s:set_current_mapping_visibility(!s:get_current_mapping_visibility())
  call s:action_update(0, 0)
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista commits',
          \ 'description': [
          \   'List commits of a gist',
          \ ],
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#option#complete_gistid'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#commits#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#option#assign_gistid(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#commits#default_options),
        \ options,
        \)
  call gista#command#commits#open(options)
endfunction
function! gista#command#commits#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

function! gista#command#commits#define_highlights() abort
  highlight default link GistaPartialMarker    Comment
  highlight default link GistaDownloadedMarker Special
  highlight default link GistaDateTime         Comment
  highlight default link GistaGistVersion      Tag
  highlight default link GistaMapping          Comment
  highlight default link GistaAdditions        Special
  highlight default link GistaDeletions        Constant
endfunction
function! gista#command#commits#define_syntax() abort
  syntax match GistaMapping /^|.*$/
  syntax match GistaCommitLine /^[=\-].*[a-zA-Z0-9]\+$/
  syntax match GistaGistVersion /[a-zA-Z0-9]\+$/
        \ display contained containedin=GistaCommitLine
  syntax match GistaCommitMeta /^[=\-] \d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2}:\d\{2})/
        \ display contained containedin=GistaCommitLine
  syntax match GistaPartialMarker /^-/
        \ display contained containedin=GistaCommitMeta
  syntax match GistaDownloadedMarker /^=/
        \ display contained containedin=GistaCommitMeta
  syntax match GistaDateTime /\d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2}:\d\{2})/
        \ display contained containedin=GistaCommitMeta
  syntax match GistaAdditions /\d\+ additions/
        \ display contained containedin=GistaCommitLine
  syntax match GistaDeletions /\d\+ deletions/
        \ display contained containedin=GistaCommitLine
endfunction

function! gista#command#commits#get_status_string() abort
  return printf('%s:%s',
        \ b:gista.apiname,
        \ b:gista.gistid,
        \)
endfunction

augroup vim_gista_update_commits
  autocmd!
  autocmd User GistaJson call s:on_GistaUpdate()
  autocmd User GistaOpen call s:on_GistaUpdate()
  autocmd User GistaBrowse call s:on_GistaUpdate()
  autocmd User GistaPost call s:on_GistaUpdate()
  autocmd User GistaPatch call s:on_GistaUpdate()
  autocmd User GistaRename call s:on_GistaUpdate()
  autocmd User GistaRemove call s:on_GistaUpdate()
  autocmd User GistaDelete call s:on_GistaUpdate()
  autocmd User GistaFork call s:on_GistaUpdate()
  autocmd User GistaStar call s:on_GistaUpdate()
  autocmd User GistaUnstar call s:on_GistaUpdate()
augroup END

call gista#define_variables('command#commits', {
      \ 'default_options': {},
      \ 'default_lookup': '',
      \ 'default_mapping_visibility': 0,
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
      \ 'show_status_string_in_prologue': 1,
      \})
