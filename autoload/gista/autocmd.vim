function! s:is_patchable(gista) abort
  let client = gista#client#get()
  let username = client.get_authorized_username()
  let result = gista#command#json#call({
        \ 'gistid': a:gista.gistid,
        \})
  if empty(result)
    return 0
  endif
  if result.gistid =~# '^[^/]\+/[^/]\+$'
    " gistid with version cannot be patchable
    return 'A file content of a gist with a specific version cannot be patched'
  endif
  return get(get(result.gist, 'owner', {}), 'login') ==# username
        \ ? ''
        \ : 'An owner of a gist and a current authorized username is miss-matched'
endfunction

function! s:on_SourceCmd(gista) abort
  let content = getbufline(expand('<amatch>'), 1, '$')
  try
    let tempfile = tempname()
    call writefile(content, tempfile)
    execute printf('source %s', tempfile)
  finally
    if filereadable(tempfile)
      call delete(tempfile)
    endif
  endtry
endfunction
function! s:on_BufReadCmd(gista) abort
  let content_type = get(a:gista, 'content_type', '')
  if content_type ==# 'raw'
    call gista#command#open#edit({
          \ 'gistid': a:gista.gistid,
          \ 'filename': a:gista.filename,
          \ 'cache': !v:cmdbang,
          \})
  elseif content_type ==# 'json'
    call gista#command#json#edit({
          \ 'gistid': a:gista.gistid,
          \ 'cache': !v:cmdbang,
          \})
  else
    call gista#throw(printf(
          \ 'Unknown content_type "%s" is specified',
          \ content_type,
          \))
  endif
endfunction
function! s:on_FileReadCmd(gista) abort
  let content_type = get(a:gista, 'content_type', '')
  if content_type ==# 'raw'
    call gista#command#open#read({
          \ 'gistid': a:gista.gistid,
          \ 'filename': a:gista.filename,
          \ 'cache': !v:cmdbang,
          \})
  elseif content_type ==# 'json'
    call gista#command#json#read({
          \ 'gistid': a:gista.gistid,
          \ 'cache': !v:cmdbang,
          \})
  else
    call gista#throw(printf(
          \ 'Unknown content_type "%s" is specified',
          \ content_type,
          \))
  endif
endfunction

function! s:on_BufWriteCmd(gista) abort
  let content_type = get(a:gista, 'content_type', '')
  if content_type ==# 'raw'
    let errormsg = s:is_patchable(a:gista)
    if !empty(errormsg)
      call gista#util#prompt#error(errormsg)
      call gista#util#prompt#warn(
            \ 'Use ":Gista fork" to fork the gist or ":Gista post" to create a new Gist',
            \)
      return
    endif
    let filename = a:gista.filename
    let content = gista#util#ensure_eol(join(getline(1, '$'), "\n"))
    let result = gista#command#patch#call({
          \ 'gistid': a:gista.gistid,
          \ 'filenames': [filename],
          \ 'contents': [{ 'content': content }],
          \ 'force': v:cmdbang,
          \})
    if empty(result)
      call gista#util#prompt#warn(printf(join([
            \   'Use ":w!" to post changes to %s forcedly or :Gista post to create a new Gist',
            \ ]),
            \ a:gista.apiname,
            \))
    else
      set nomodified
    endif
  else
    call gista#throw(printf(
          \ 'Unknown content_type "%s" is specified',
          \ content_type,
          \))
  endif
endfunction
function! s:on_FileWriteCmd(gista) abort
  let content_type = get(a:gista, 'content_type', '')
  if content_type ==# 'raw'
    let errormsg = s:is_patchable(a:gista)
    if !empty(errormsg)
      call gista#util#prompt#error(errormsg)
      call gista#util#prompt#warn(
            \ 'Use ":Gista fork" to fork the gist or ":Gista post" to create a new Gist',
            \)
      return
    endif
    let filename = a:gista.filename
    let content = gista#util#ensure_eol(join(getline("'[", "']"), "\n"))
    let result = gista#command#patch#call({
          \ 'gistid': a:gista.gistid,
          \ 'filenames': [filename],
          \ 'contents': [{ 'content': content }],
          \ 'force': v:cmdbang,
          \})
    if empty(result)
      call gista#util#prompt#warn(printf(join([
            \   'Use ":w!" to post changes to %s forcedly or ":Gista post" to create a new Gist',
            \ ]),
            \ a:gista.apiname,
            \))
    else
      set nomodified
    endif
  else
    call gista#throw(printf(
          \ 'Unknown content_type "%s" is specified',
          \ content_type,
          \))
  endif
endfunction

function! gista#autocmd#call(name) abort
  let fname = 's:on_' . a:name
  if !exists('*' . fname)
    call gista#throw(printf(
          \ 'No autocmd function "%s" is found.', fname
          \))
  endif
  let gista = gista#get('<afile>')
  let session = gista#client#session({
        \ 'apiname':  get(gista, 'apiname', ''),
        \ 'username': get(gista, 'username', 0),
        \})
  try
    if session.enter()
      call call(fname, [gista])
    endif
  finally
    call session.exit()
  endtry
endfunction

" Configure variables
call gista#define_variables('autocmd', {})
