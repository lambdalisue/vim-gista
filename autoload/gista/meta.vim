let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:C = s:V.import('Vim.Compat')

let s:CACHE_DISABLED = 0
let s:CACHE_ENABLED = 1
let s:CACHE_FORCED = 2

" A content size limit for downloading via HTTP
" https://developer.github.com/v3/gists/#truncation
let s:CONTENT_SIZE_LIMIT = 10 * 1024 * 1024

function! gista#meta#validate_gistid(gistid) abort
  call gista#util#validate#not_empty(
        \ a:gistid,
        \ 'A gist ID cannot be empty',
        \)
  call gista#util#validate#pattern(
        \ a:gistid, '^\w\{,20}\%(/\w\+\)\?$',
        \ 'A gist ID "%value" requires to follow "%pattern"'
        \)
endfunction
function! gista#meta#validate_filename(filename) abort
  call gista#util#validate#not_empty(
        \ a:filename,
        \ 'A filename cannot be empty',
        \)
endfunction
function! gista#meta#validate_lookup(lookup) abort
  let client = gista#client#get()
  let username = client.get_authorized_username()
  if !empty(username)
        \ && (a:lookup ==# username || a:lookup ==# username . '/starred')
    return
  endif
  call gista#util#validate#pattern(
        \ a:lookup, '^\w*$',
        \ 'A lookup "%value" requires to follow "%pattern"'
        \)
endfunction

function! gista#meta#get_valid_gistid(gistid) abort
  if empty(a:gistid)
    redraw
    let gistid = gista#util#prompt#ask(
          \ 'Please input a gist id: ', '',
          \ 'customlist,gista#meta#complete_gistid',
          \)
    if empty(gistid)
      call gista#util#prompt#throw('Cancel')
    endif
  else
    let gistid = a:gistid
  endif
  call gista#meta#validate_gistid(gistid)
  return gistid
endfunction
function! gista#meta#get_valid_filename(gist_or_gistid, filename) abort
  if empty(a:filename)
    if type(a:gist_or_gistid) == type('')
      let client = gista#client#get()
      let gistid = gista#meta#get_valid_gistid(a:gist_or_gistid)
      let gist   = client.gist_cache.get(gistid, {})
    else
      let gist = a:gist_or_gistid
    endif
    let filenames = gista#meta#get_available_filenames(gist)
    if len(filenames) == 1
      let filename = filenames[0]
    elseif len(filenames) > 0
      redraw
      let ret = gista#util#prompt#inputlist(
            \ 'Please select a filename: ',
            \ filenames,
            \)
      if ret == 0
        call gista#util#prompt#throw('Cancel')
      endif
      let filename = filenames[ret - 1]
    else
      redraw
      let filename = gista#util#prompt#ask(
            \ 'Please input a filename: ', '',
            \ 'customlist,gista#meta#complete_filename',
            \)
      if empty(filename)
        call gista#util#prompt#throw('Cancel')
      endif
    endif
  else
    let filename = a:filename
  endif
  call gista#meta#validate_filename(filename)
  return filename
endfunction
function! gista#meta#get_valid_lookup(lookup) abort
  let client = gista#client#get()
  let username = client.get_authorized_username()
  let lookup = empty(a:lookup)
        \ ? empty(g:gista#command#list#default_lookup)
        \   ? empty(username)
        \     ? 'public'
        \     : username
        \   : g:gista#command#list#default_lookup
        \ : a:lookup
  let lookup = !empty(username) && lookup ==# 'starred'
        \ ? username . '/starred'
        \ : lookup
  call gista#meta#validate_lookup(lookup)
  return lookup
endfunction

function! gista#meta#get_available_gistids() abort
  let client = gista#client#get()
  let lookup = client.get_authorized_username()
  let lookup = empty(lookup) ? 'public' : lookup
  let index = gista#resource#gists#list(lookup, {
        \ 'cache': s:CACHE_FORCED,
        \})
  return map(copy(index.entries), 'v:val.id')
endfunction
function! gista#meta#get_available_filenames(gist) abort
  " Remove files more thant 10 MiB which cannot download with HTTP protocol
  return filter(
        \ keys(get(a:gist, 'files', {})),
        \ 'a:gist.files[v:val].size < s:CONTENT_SIZE_LIMIT'
        \)
endfunction

function! gista#meta#complete_apiname(arglead, cmdline, cursorpos, ...) abort
  let apinames = gista#client#_get_available_apiname()
  return filter(apinames, 'v:val =~# "^" . a:arglead')
endfunction
function! gista#meta#complete_username(arglead, cmdline, cursorpos, ...) abort
  let options = extend({
        \ 'apiname': '',
        \}, get(a:000, 0, {}),
        \)
  let client = gista#client#get()
  let apiname = empty(options.apiname)
        \ ? client.apiname
        \ : options.apiname
  try
    let usernames = gista#client#_get_available_username(apiname)
    return filter(usernames, 'v:val =~# "^" . a:arglead')
  catch /^vim-gista: ValidationError:/
    return []
  endtry
endfunction
function! gista#meta#complete_gistid(arglead, cmdline, cursorpos, ...) abort
  return filter(
        \ gista#meta#get_available_gistids(),
        \ 'v:val =~# "^" . a:arglead',
        \)
endfunction
function! gista#meta#complete_filename(arglead, cmdline, cursorpos, ...) abort
  let options = extend({
        \ 'gistid': '',
        \}, get(a:000, 0, {}),
        \)
  let gistid = options.gistid
  try
    call gista#meta#validate_gistid(gistid)
    let gist = gista#resource#gists#get(gistid, {
          \ 'cache': s:CACHE_FORCED,
          \})
    if gist._gista_fetched == 0
      let client = gista#client#get()
      let username = client.get_authorized_username()
      let gist = gista#resource#gists#_retrieve_entry_entry(client, gistid, [
            \ username,
            \ empty(username) ? '' : username . '/starred',
            \ 'public',
            \])
    endif
    let filenames = gista#meta#get_available_filenames(gist)
    return filter(filenames, 'v:val =~# "^" . a:arglead')
  catch /^vim-gista: ValidationError:/
    return []
  endtry
endfunction
function! gista#meta#complete_lookup(arglead, cmdline, cursorpos, ...) abort
  try
    let client = gista#client#get()
    let lookups = extend([
          \ client.get_authorized_username(),
          \ 'starred',
          \ 'public',
          \], client.token_cache.keys()
          \)
    let lookups = uniq(filter(lookups, '!empty(v:val)'))
    return filter(lookups, 'v:val =~# "^" . a:arglead')
  catch /^vim-gista: ValidationError:/
    return []
  endtry
endfunction

function! gista#meta#guess_filename(expr) abort
  let gista = s:C.getbufvar(a:expr, 'gista', {})
  let filename = expand(a:expr)
  if has_key(gista, 'filename')
    return gista.filename
  elseif filename =~# '^gista:.*:.*:.*$'
    return matchstr(filename, '^gista:.*:.*:\zs.*\ze$')
  else
    return filename
  endif
endfunction
function! gista#meta#assign_apiname(options, expr) abort
  if has_key(a:options, 'apiname')
    return
  endif
  let gista    = s:C.getbufvar(a:expr, 'gista', {})
  let filename = expand(a:expr)
  if has_key(gista, 'apiname')
    let a:options.apiname = gista.apiname
  elseif filename =~# '^gista-file:.*:.*:.*$'
    let a:options.apiname = matchstr(filename, '^gista-file:\zs.*\ze:.*:.*$')
  endif
endfunction
function! gista#meta#assign_gistid(options, expr) abort
  if has_key(a:options, 'gistid')
    return
  endif
  let gista    = s:C.getbufvar(a:expr, 'gista', {})
  let filename = expand(a:expr)
  if has_key(gista, 'gistid')
    let a:options.gistid = gista.gistid
  elseif filename =~# '^gista-file:.*:.*:.*$'
    let a:options.gistid = matchstr(filename, '^gista-file:.*:\zs.*\ze:.*$')
  endif
endfunction
function! gista#meta#assign_filename(options, expr) abort
  if has_key(a:options, 'filename')
    return
  endif
  let gista    = s:C.getbufvar(a:expr, 'gista', {})
  let filename = expand(a:expr)
  if has_key(gista, 'filename')
    let a:options.filename = gista.filename
  elseif filename =~# '^gista-file:.*:.*:.*$'
    let a:options.filename = matchstr(filename, '^gista-file:.*:.*:\zs.*\ze$')
  endif
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
