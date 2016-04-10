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
      \ '<Plug>(gista-UPDATE)': 'Update the buffer content without cache',
      \ '<Plug>(gista-next-mode)': 'Select next mode',
      \ '<Plug>(gista-prev-mode)': 'Select previous mode',
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
      \ '<Plug>(gista-rename)': 'Rename a file in a selected gist',
      \ '<Plug>(gista-RENAME)': 'Rename a file in a selected gist (forcedly)',
      \ '<Plug>(gista-remove)': 'Remove a file in a selected gist from the remote',
      \ '<Plug>(gista-REMOVE)': 'Remove a file in a selected gist from the remote (forcedly)',
      \ '<Plug>(gista-delete)': 'Delete a selected gist from the remote',
      \ '<Plug>(gista-DELETE)': 'Delete a selected gist from the remote (forcedly)',
      \ '<Plug>(gista-fork)': 'Fork a selected gist',
      \ '<Plug>(gista-star)': 'Star a selected gist',
      \ '<Plug>(gista-unstar)': 'Unstar a selected gist',
      \ '<Plug>(gista-commits)': 'Open commits of a selected gist',
      \}
let s:entry_offset = 0

function! s:truncate(str, width) abort
  let suffix = strdisplaywidth(a:str) > a:width ? '...' : '   '
  return s:String.truncate(a:str, a:width - 4) . suffix
endfunction
function! s:format_entry(entry) abort
  let gistid = a:entry.public
        \ ? 'gistid:' . a:entry.id
        \ : 'gistid:' . s:PRIVATE_GISTID
  let fetched = a:entry._gista_fetched  ? '=' : '-'
  let starred = get(a:entry, 'is_starred') ? '*' : ' '
  let mode    = s:get_current_mode(a:entry)
  let prefix = fetched . ' ' . mode . ' ' . starred . ' '
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
function! s:get_entry(index) abort
  let index = a:index - s:entry_offset
  return index >= 0 ? get(b:gista.entries, index, {}) : {}
endfunction
function! s:sort_entries(entries, ...) abort
  let field = get(a:000, 0, '')
  if empty(field)
    let index = s:get_current_mode_index()
    let field = s:MODES[index]
  endif
  let namespace = {
        \ 'field': field
        \}
  return reverse(sort(a:entries, function('s:_sort_entries'), namespace))
endfunction
function! s:_sort_entries(lhs, rhs) dict abort
  let lhs = a:lhs[self.field]
  let rhs = a:rhs[self.field]
  return lhs ==# rhs ? 0 : lhs > rhs ? 1 : -1
endfunction

function! s:get_current_mode_index() abort
  if !exists('s:current_mode_index')
    let index = index(s:MODES, g:gista#command#list#default_mode)
    if index == -1
      call gista#throw(printf(
            \ 'An invalid mode "%s" is specified to g:gista#command#list#default_mode',
            \ g:gista#command#list#default_mode,
            \))
    endif
    let s:current_mode_index = index
  endif
  return s:current_mode_index
endfunction
function! s:set_current_mode_index(index) abort
  let s:current_mode_index = a:index
endfunction
function! s:get_current_mode(entry) abort
  let lmode = s:MODES[s:get_current_mode_index()]
  if lmode ==# 'created_at' || lmode ==# 'updated_at'
    let datetime = a:entry[lmode]
    let mode = substitute(
          \ datetime,
          \ '\v\d{2}(\d{2})-(\d{2})-(\d{2})T(\d{2}:\d{2}:\d{2})Z',
          \ '\1/\2/\3(\4)',
          \ ''
          \)
    return mode
  endif
endfunction
function! s:get_current_mapping_visibility() abort
  if exists('s:current_mapping_visibility')
    return s:current_mapping_visibility
  endif
  let s:current_mapping_visibility =
        \ g:gista#command#list#default_mapping_visibility
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
        \ :call <SID>action('update', 1)<CR>
  nnoremap <buffer><silent> <Plug>(gista-UPDATE)
        \ :call <SID>action('update', 0)<CR>
  nnoremap <buffer><silent> <Plug>(gista-next-mode)
        \ :call <SID>action('next_mode')<CR>
  nnoremap <buffer><silent> <Plug>(gista-prev-mode)
        \ :call <SID>action('prev_mode')<CR>
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
  noremap <buffer><silent> <Plug>(gista-rename)
        \ :call <SID>action('rename', 0)<CR>
  noremap <buffer><silent> <Plug>(gista-RENAME)
        \ :call <SID>action('rename', 1)<CR>
  noremap <buffer><silent> <Plug>(gista-remove)
        \ :call <SID>action('remove', 0)<CR>
  noremap <buffer><silent> <Plug>(gista-REMOVE)
        \ :call <SID>action('remove', 1)<CR>
  noremap <buffer><silent> <Plug>(gista-delete)
        \ :call <SID>action('delete', 0)<CR>
  noremap <buffer><silent> <Plug>(gista-DELETE)
        \ :call <SID>action('delete', 1)<CR>
  noremap <buffer><silent> <Plug>(gista-star)
        \ :call <SID>action('star')<CR>
  noremap <buffer><silent> <Plug>(gista-unstar)
        \ :call <SID>action('unstar')<CR>
  noremap <buffer><silent> <Plug>(gista-fork)
        \ :call <SID>action('fork')<CR>
  noremap <buffer><silent> <Plug>(gista-commits)
        \ :call <SID>action('commits')<CR>
endfunction
function! s:define_default_mappings() abort
  nmap <buffer> q <Plug>(gista-quit)
  nmap <buffer> <C-n> <Plug>(gista-next-mode)
  nmap <buffer> <C-p> <Plug>(gista-prev-mode)
  nmap <buffer> ? <Plug>(gista-toggle-mapping-visibility)
  nmap <buffer> <C-l> <Plug>(gista-redraw)
  nmap <buffer> <F5>   <Plug>(gista-update)
  nmap <buffer> <S-F5> <Plug>(gista-UPDATE)
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
  map <buffer> rr <Plug>(gista-rename)
  map <buffer> RR <Plug>(gista-RENAME)
  map <buffer> df <Plug>(gista-remove)
  map <buffer> DF <Plug>(gista-REMOVE)
  map <buffer> dd <Plug>(gista-delete)
  map <buffer> DD <Plug>(gista-DELETE)
  map <buffer> ++ <Plug>(gista-star)
  map <buffer> -- <Plug>(gista-unstar)
  map <buffer> ff <Plug>(gista-fork)
  map <buffer> cc <Plug>(gista-commits)
endfunction

function! gista#command#list#call(...) abort
  let options = extend({
        \ 'lookup': '',
        \ 'cache': 1,
        \}, get(a:000, 0, {}))
  try
    let lookup = gista#resource#local#get_valid_lookup(options.lookup)
    let index  = gista#resource#remote#list(lookup, options)
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return {}
  endtry
  " apply 'is_starred' field
  let client = gista#client#get()
  let username = client.get_authorized_username()
  if !empty(username)
    let starred = client.starred_cache.get(username, {})
    let index.entries = map(
          \ deepcopy(index.entries),
          \ 'extend(v:val, { "is_starred": get(starred, v:val.id) })',
          \)
  endif
  let result = {
        \ 'index': index,
        \ 'lookup': lookup,
        \}
  return result
endfunction
function! gista#command#list#open(...) abort
  let options = extend({
        \ 'opener': '',
        \ 'cache': 1,
        \}, get(a:000, 0, {}))
  let result = gista#command#list#call(options)
  if empty(result)
    return
  endif
  let client = gista#client#get()
  let apiname = client.apiname
  let username = client.get_authorized_username()
  let opener = empty(options.opener)
        \ ? g:gista#command#list#default_opener
        \ : options.opener
  let bufname = printf('gista-list:%s:%s',
        \ client.apiname, result.lookup,
        \)
  call gista#util#buffer#open(bufname, {
        \ 'opener': opener . (options.cache ? '' : '!'),
        \ 'group': 'manipulation_panel',
        \})
  let b:gista = {
        \ 'winwidth': winwidth(0),
        \ 'apiname': apiname,
        \ 'username': username,
        \ 'lookup': result.lookup,
        \ 'entries': s:sort_entries(result.index.entries),
        \ 'options': s:Dict.omit(options, ['cache']),
        \ 'content_type': 'list',
        \}
  call s:define_plugin_mappings()
  if g:gista#command#list#enable_default_mappings
    call s:define_default_mappings()
  endif
  augroup vim_gista_list
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> call gista#command#list#open(b:gista.options)
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
  silent call gista#util#doautocmd('List', result)
endfunction
function! gista#command#list#update(...) abort
  if &filetype !=# 'gista-list'
    call gista#throw(
          \ 'update() requires to be called in a gista-list buffer'
          \)
  endif
  let options = extend(copy(b:gista.options), get(a:000, 0, {}))
  let options = extend(options, {
        \ 'lookup': b:gista.lookup,
        \})
  let result = gista#command#list#call(options)
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
        \ 'lookup': result.lookup,
        \ 'entries': s:sort_entries(result.index.entries),
        \ 'options': options,
        \ 'content_type': 'list',
        \}
  call gista#command#list#redraw()
  silent call gista#util#doautocmd('ListUpdate', result)
endfunction
function! gista#command#list#redraw() abort
  if &filetype !=# 'gista-list'
    call gista#throw(
          \ 'redraw() requires to be called in a gista-list buffer'
          \)
  endif
  let prologue = s:List.flatten([
        \ g:gista#command#list#show_status_string_in_prologue
        \   ? [gista#command#list#get_status_string() . ' | Press ? to toggle a mapping help']
        \   : [],
        \ s:get_current_mapping_visibility()
        \   ? map(gista#util#mapping#help(s:MAPPING_TABLE), '"| " . v:val')
        \   : []
        \])
  redraw
  echo 'Formatting gist entries to display ...'
  let contents = map(
        \ copy(b:gista.entries),
        \ 's:format_entry(v:val)'
        \)
  let s:entry_offset = len(prologue)
  call gista#util#buffer#edit_content(extend(prologue, contents))
  redraw | echo
endfunction

function! s:on_VimResized() abort
  call gista#command#list#redraw()
endfunction
function! s:on_WinEnter() abort
  if b:gista.winwidth != winwidth(0)
    call gista#command#list#redraw()
  endif
endfunction
function! s:on_GistaUpdate() abort
  let winnum = winnr()
  keepjump windo
        \ if &filetype ==# 'gista-list' |
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
        \ ? g:gista#command#list#default_entry_opener
        \ : opener
  let [opener, anchor] = get(
        \ g:gista#command#list#entry_openers,
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
        \ ? g:gista#command#list#default_entry_opener
        \ : opener
  let [opener, anchor] = get(
        \ g:gista#command#list#entry_openers,
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
function! s:action_rename(startline, endline, ...) abort
  let force = get(a:000, 0, 1)
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
        call gista#command#rename#call({
              \ 'gist': entry,
              \ 'force': force,
              \})
      endfor
    endif
  finally
    call session.exit()
  endtry
endfunction
function! s:action_remove(startline, endline, ...) abort
  let force = get(a:000, 0, 1)
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
        call gista#command#remove#call({
              \ 'gist': entry,
              \ 'force': force,
              \})
      endfor
    endif
  finally
    call session.exit()
  endtry
endfunction
function! s:action_delete(startline, endline, ...) abort
  let force = get(a:000, 0, 1)
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
      echo printf(
            \ "The following gists will be deleted\n%s",
            \ join(map(copy(entries), '"- " . v:val.id'), "\n"),
            \)
      if gista#util#prompt#confirm("Are you sure to continue?")
        for entry in entries
          call gista#command#delete#call({
                \ 'gist': entry,
                \ 'force': force,
                \ 'confirm': 0,
                \})
        endfor
      else
        call gista#util#prompt#warn('Canceled')
      endif
    endif
  finally
    call session.exit()
  endtry
endfunction
function! s:action_star(startline, endline, ...) abort
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
        call gista#command#star#call({
              \ 'gist': entry,
              \})
      endfor
    endif
  finally
    call session.exit()
  endtry
endfunction
function! s:action_unstar(startline, endline, ...) abort
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
        call gista#command#unstar#call({
              \ 'gist': entry,
              \})
      endfor
    endif
  finally
    call session.exit()
  endtry
endfunction
function! s:action_fork(startline, endline, ...) abort
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
        call gista#command#fork#call({
              \ 'gist': entry,
              \})
      endfor
    endif
  finally
    call session.exit()
  endtry
endfunction
function! s:action_commits(startline, endline, ...) abort
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
        call gista#command#commits#open({
              \ 'gist': entry,
              \})
      endfor
    endif
  finally
    call session.exit()
  endtry
endfunction
function! s:action_redraw(startline, endline, ...) abort
  call gista#command#list#redraw()
endfunction
function! s:action_update(startline, endline, ...) abort
  let cache = get(a:000, 0, 1)
  call gista#command#list#update({ 'cache': cache })
endfunction
function! s:action_next_mode(startline, endline, ...) abort
  let index = s:get_current_mode_index() + 1
  let index = index >= len(s:MODES) ? 0 : index
  call s:set_current_mode_index(index)
  call s:action_update(0, 0)
endfunction
function! s:action_prev_mode(startline, endline, ...) abort
  let index = s:get_current_mode_index() - 1
  let index = index < 0 ? len(s:MODES) - 1 : index
  call s:set_current_mode_index(index)
  call s:action_update(0, 0)
endfunction
function! s:action_toggle_mapping_visibility(startline, endline, ...) abort
  call s:set_current_mapping_visibility(!s:get_current_mapping_visibility())
  call s:action_update(0, 0)
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista[!] list',
          \ 'description': [
          \   'List gists of a paricular lookup.',
          \   'A bang (!) is a short form of "--no-cache --no-since".',
          \ ],
          \})
    call s:parser.add_argument(
          \ 'lookup',
          \ 'Gists lookup', {
          \   'complete': function('gista#option#complete_lookup'), 
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
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
          \   'type': s:ArgumentParser.types.any,
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
  highlight default link GistaPartialMarker    Comment
  highlight default link GistaDownloadedMarker Special
  highlight default link GistaStarredMarker    WarningMsg
  highlight default link GistaDateTime         Comment
  highlight default link GistaGistIDPublic     Tag
  highlight default link GistaGistIDPrivate    Constant
  highlight default link GistaMapping          Comment
endfunction
function! gista#command#list#define_syntax() abort
  syntax match GistaMapping /^|.*$/
  syntax match GistaLine /^[=\-].*gistid:.\{,32}\%(\/[a-zA-Z0-9]\+\)\?$/
  syntax match GistaGistIDPublic /gistid:[a-zA-Z0-9_\-]\{,32}\%(\/[a-zA-Z0-9]\+\)\?$/
        \ display contained containedin=GistaLine
  syntax match GistaGistIDPrivate /gistid:\*\{32}$/
        \ display contained containedin=GistaLine
  syntax match GistaMeta /^[=\-] \d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2}:\d\{2}) [ \*]/
        \ display contained containedin=GistaLine
  syntax match GistaPartialMarker /^-/
        \ display contained containedin=GistaMeta
  syntax match GistaDownloadedMarker /^=/
        \ display contained containedin=GistaMeta
  syntax match GistaDateTime /\d\{2}\/\d\{2}\/\d\{2}(\d\{2}:\d\{2}:\d\{2})/
        \ display contained containedin=GistaMeta
  syntax match GistaStarredMarker /[ \*]/
        \ display contained containedin=GistaMeta
endfunction
function! gista#command#list#format_entry(entry, starred_cache) abort
  return s:format_entry(a:entry, a:starred_cache)
endfunction

function! gista#command#list#get_status_string() abort
  return printf('%s:%s | Mode: %s',
        \ b:gista.apiname,
        \ b:gista.lookup,
        \ s:MODES[s:get_current_mode_index()]
        \)
endfunction
function! gista#command#list#sort_entries(...) abort
  return call('s:sort_entries', a:000)
endfunction

augroup vim_gista_update_list
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

call gista#define_variables('command#list', {
      \ 'default_options': {},
      \ 'default_lookup': '',
      \ 'default_mode': 'created_at',
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
