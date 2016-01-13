let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:L = s:V.import('Data.List')
let s:C = s:V.import('Vim.Compat')

function! gista#option#get_valid_gistid(options) abort
  let gist = get(a:options, 'gist', {})
  if !empty(gist)
    let gistid = gist.id
  else
    let gistid = get(a:options, 'gistid', '')
    if empty(gistid)
      redraw
      let gistid = gista#util#prompt#ask(
            \ 'Please input a gist id: ', '',
            \ 'customlist,gista#option#complete_gistid',
            \)
      if empty(gistid)
        call gista#util#prompt#throw('Cancel')
      endif
    endif
  endif
  call gista#resource#local#validate_gistid(gistid)
  return gistid
endfunction
function! gista#option#get_valid_filename(options) abort
  let filename = get(a:options, 'filename', '')
  if empty(filename)
    if has_key(a:options, 'gist')
      let gist = a:options.gist
    else
      let client = gista#client#get()
      let gistid = gista#option#get_valid_gistid(a:options)
      let gist   = client.gist_cache.get(gistid, {})
    endif
    let filenames = gista#resource#local#get_available_filenames(gist)
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
            \ 'customlist,gista#option#complete_filename',
            \)
      if empty(filename)
        call gista#util#prompt#throw('Cancel')
      endif
    endif
  endif
  call gista#resource#local#validate_filename(filename)
  return filename
endfunction
function! gista#option#get_valid_lookup(options) abort
  let lookup = get(a:options, 'lookup', '')
  let client = gista#client#get()
  let username = client.get_authorized_username()
  let lookup = empty(lookup)
        \ ? empty(username)
        \   ? 'public'
        \   : username
        \ : lookup
  let lookup = !empty(username) && lookup ==# 'starred'
        \ ? username . '/starred'
        \ : lookup
  call gista#resource#local#validate_lookup(lookup)
  return lookup
endfunction

function! gista#option#guess_filename(expr) abort
  let gista = s:C.getbufvar(a:expr, 'gista', {})
  let filename = expand(a:expr)
  if has_key(gista, 'filename')
    return gista.filename
  elseif filename =~# '^gista-file:.*:.*:.*$'
    return matchstr(filename, '^gista-file:.*:.*:\zs.*\ze$')
  else
    return filename
  endif
endfunction
function! gista#option#assign_apiname(options, expr) abort
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
function! gista#option#assign_gistid(options, expr) abort
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
function! gista#option#assign_filename(options, expr) abort
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

function! gista#option#complete_apiname(arglead, cmdline, cursorpos, ...) abort
  let apinames = gista#client#get_available_apinames()
  return filter(apinames, 'v:val =~# "^" . a:arglead')
endfunction
function! gista#option#complete_username(arglead, cmdline, cursorpos, ...) abort
  let options = extend({
        \ 'apiname': '',
        \}, get(a:000, 0, {}),
        \)
  let client = gista#client#get()
  let apiname = empty(options.apiname)
        \ ? client.apiname
        \ : options.apiname
  try
    let usernames = gista#client#get_available_usernames(apiname)
    return filter(usernames, 'v:val =~# "^" . a:arglead')
  catch /^vim-gista: ValidationError:/
    return []
  endtry
endfunction
function! gista#option#complete_gistid(arglead, cmdline, cursorpos, ...) abort
  return filter(
        \ gista#resource#local#get_available_gistids(),
        \ 'v:val =~# "^" . a:arglead',
        \)
endfunction
function! gista#option#complete_filename(arglead, cmdline, cursorpos, ...) abort
  let options = get(a:000, 0, {})
  let gistid = get(options, 'gistid', '')
  try
    let gist = gista#resource#local#get(gistid)
    if gist._gista_fetched == 0
      let client = gista#client#get()
      let username = client.get_authorized_username()
      let gist = gista#resource#local#retrieve_index_entry(gistid)
    endif
    let filenames = gista#resource#local#get_available_filenames(gist)
    return filter(filenames, 'v:val =~# "^" . a:arglead')
  catch /^vim-gista: ValidationError:/
    return []
  endtry
endfunction
function! gista#option#complete_lookup(arglead, cmdline, cursorpos, ...) abort
  try
    let client = gista#client#get()
    let lookups = extend([
          \ client.get_authorized_username(),
          \ 'starred',
          \ 'public',
          \], client.token_cache.keys()
          \)
    let lookups = s:L.uniq(filter(lookups, '!empty(v:val)'))
    return filter(lookups, 'v:val =~# "^" . a:arglead')
  catch /^vim-gista: ValidationError:/
    return []
  endtry
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
