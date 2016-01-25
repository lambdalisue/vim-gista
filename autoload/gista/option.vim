let s:V = gista#vital()
let s:List = s:V.import('Data.List')

function! gista#option#assign_apiname(options, expr) abort
  if has_key(a:options, 'apiname')
    return
  endif
  let gista = gista#get(a:expr)
  if has_key(gista, 'apiname')
    let a:options.apiname = gista.apiname
  endif
endfunction
function! gista#option#assign_gistid(options, expr) abort
  if has_key(a:options, 'gistid')
    return
  endif
  let gista = gista#get(a:expr)
  if has_key(gista, 'gistid')
    let a:options.gistid = gista.gistid
  endif
endfunction
function! gista#option#assign_filename(options, expr) abort
  if has_key(a:options, 'filename')
    return
  endif
  let gista = gista#get(a:expr)
  if has_key(gista, 'filename')
    let a:options.filename = gista.filename
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
    let lookups = s:List.uniq(filter(lookups, '!empty(v:val)'))
    return filter(lookups, 'v:val =~# "^" . a:arglead')
  catch /^vim-gista: ValidationError:/
    return []
  endtry
endfunction
