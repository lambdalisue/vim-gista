let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:C = s:V.import('Vim.Compat')

function! s:is_patchable(gista) abort
  let client = gista#client#get()
  let username = client.get_authorized_username()
  let [gist, gistid] = gista#command#json#call({
        \ 'gistid': a:gista.gistid,
        \})
  return get(get(gist, 'owner', {}), 'login') ==# username
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
    call gista#util#prompt#throw(printf(
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
    call gista#util#prompt#throw(printf(
          \ 'Unknown content_type "%s" is specified',
          \ content_type,
          \))
  endif
endfunction

function! s:on_BufWriteCmd(gista) abort
  let content_type = get(a:gista, 'content_type', '')
  if content_type ==# 'raw'
    if !s:is_patchable(a:gista)
      call gista#util#prompt#error(printf(
            \ 'An owner of gist %s and a current authorized username is miss-matched',
            \ a:gista.gistid,
            \))
      call gista#util#prompt#warn(
            \ 'Use ":Gista fork" to fork the gist or ":Gista post" to create a new Gist',
            \)
      return
    endif
    let filename = a:gista.filename
    let content = gista#util#ensure_eol(join(getline(1, '$'), "\n"))
    let gist = gista#command#patch#call({
          \ 'gistid': a:gista.gistid,
          \ 'filenames': [filename],
          \ 'contents': [{ 'content': content }],
          \ 'force': v:cmdbang,
          \})
    if empty(gist)
      call gista#util#prompt#warn(printf(join([
            \   'Use ":w!" to post changes to %s forcedly or :Gista post to create a new Gist',
            \ ]),
            \ a:gista.apiname,
            \))
    else
      set nomodified
    endif
  else
    call gista#util#prompt#throw(printf(
          \ 'Unknown content_type "%s" is specified',
          \ content_type,
          \))
  endif
endfunction
function! s:on_FileWriteCmd(gista) abort
  let content_type = get(a:gista, 'content_type', '')
  if content_type ==# 'raw'
    if !s:is_patchable(a:gista)
      call gista#util#prompt#error(printf(
            \ 'An owner of gist %s and a current authorized username is miss-matched',
            \ a:gista.gistid,
            \))
      call gista#util#prompt#warn(
            \ 'Use ":Gista fork" to fork the gist or ":Gista post" to create a new Gist',
            \)
      return
    endif
    let filename = a:gista.filename
    let content = gista#util#ensure_eol(join(getline("'[", "']"), "\n"))
    let gist = gista#command#patch#call({
          \ 'gistid': a:gista.gistid,
          \ 'filenames': [filename],
          \ 'contents': [{ 'content': content }],
          \ 'force': v:cmdbang,
          \})
    if empty(gist)
      call gista#util#prompt#warn(printf(join([
            \   'Use ":w!" to post changes to %s forcedly or ":Gista post" to create a new Gist',
            \ ]),
            \ a:gista.apiname,
            \))
    else
      set nomodified
    endif
  else
    call gista#util#prompt#throw(printf(
          \ 'Unknown content_type "%s" is specified',
          \ content_type,
          \))
  endif
endfunction

function! gista#autocmd#call(name) abort
  let fname = 's:on_' . a:name
  if !exists('*' . fname)
    call gista#util#prompt#throw(printf(
          \ 'No autocmd function "%s" is found.', fname
          \))
  endif
  let filename = expand('<afile>')
  let gista = s:parse_filename(filename)
  let gista = empty(gista)
        \ ? s:C.getbufvar('<afile>', 'gista', {})
        \ : gista
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

let s:schemes = [
      \ ['^gista-file:\(.*\):\(.*\):\(.*\)$', {
      \   'apiname': 1,
      \   'gistid': 2,
      \   'filename': 3,
      \   'content_type': 'raw',
      \ }],
      \ ['^gista-json:\(.*\):\(.*\)$', {
      \   'apiname': 1,
      \   'gistid': 2,
      \   'content_type': 'json',
      \ }],
      \]
function! s:parse_filename(filename) abort
  for scheme in s:schemes
    if a:filename !~# scheme[0]
      continue
    endif
    let m = matchlist(a:filename, scheme[0])
    let o = {}
    for [key, value] in items(scheme[1])
      if type(value) == type(0)
        let o[key] = m[value]
      else
        let o[key] = value
      endif
      unlet value
    endfor
    return o
  endfor
  return {}
endfunction

" Configure variables
call gista#define_variables('autocmd', {})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
