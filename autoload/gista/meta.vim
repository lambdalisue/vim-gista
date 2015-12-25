let s:save_cpo = &cpo
set cpo&vim

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
  let client = gista#api#get_current_client()
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
    let client = gista#api#get_current_client()
    if type(a:gist_or_gistid) == type('')
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
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  let lookup = empty(a:lookup)
        \ ? empty(g:gista#api#gists#list_default_lookup)
        \   ? empty(username)
        \     ? 'public'
        \     : username
        \   : g:gista#api#gists#list_default_lookup
        \ : a:lookup
  let lookup = !empty(username) && lookup ==# 'starred'
        \ ? username . '/starred'
        \ : lookup
  call gista#meta#validate_lookup(lookup)
  return lookup
endfunction

function! gista#meta#get_available_gistids() abort
  let client = gista#api#get_current_client()
  let lookup = client.get_authorized_username()
  let lookup = empty(lookup) ? 'public' : lookup
  let content = client.head_cache.get(lookup, [])
  return map(copy(content.entries), 'v:val.id')
endfunction
function! gista#meta#get_available_filenames(gist) abort
  " Remove files more thant 10 MiB which cannot download with HTTP protocol
  return filter(
        \ keys(get(a:gist, 'files', {})),
        \ 'a:gist.files[v:val].size < s:CONTENT_SIZE_LIMIT'
        \)
endfunction

function! gista#meta#complete_apiname(arglead, cmdline, cursorpos, ...) abort
  let apinames = gista#api#_get_available_apiname()
  return filter(apinames, 'v:val =~# "^" . a:arglead')
endfunction
function! gista#meta#complete_username(arglead, cmdline, cursorpos, ...) abort
  let options = extend({
        \ 'apiname': '',
        \}, get(a:000, 0, {}),
        \)
  let apiname = empty(options.apiname)
        \ ? gista#api#get_current_apiname()
        \ : options.apiname
  try
    let usernames = gista#api#_get_available_username(apiname)
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
  try
    call gista#meta#validate_gistid(options.gistid)
    let clinet = gista#api#get_current_client()
    let gist = gista#api#gists#cache#get(options.gistid)
    if gist._gista_fetched == 0
      let gist = gista#api#gists#cache#retrieve_head(options.gistid)
    endif
    let filenames = gista#meta#get_available_filenames(gist)
    return filter(filenames, 'v:val =~# "^" . a:arglead')
  catch /^vim-gista: ValidationError:/
    return []
  endtry
endfunction
function! gista#meta#complete_lookup(arglead, cmdline, cursorpos, ...) abort
  try
    let clinet = gista#api#get_current_client()
    let lookups = extend([
          \ gista#api#get_current_username(),
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

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
