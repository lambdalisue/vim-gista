let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:C = s:V.import('Vim.Compat')

function! s:on_SourceCmd(gista) abort
  " TODO
  " Check if the file is Vim script or not
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
  elseif content_type ==# 'json_entry'
    call gista#command#json#edit({
          \ 'gistid': a:gista.gistid,
          \ 'entry': 1,
          \ 'cache': !v:cmdbang,
          \})
  elseif content_type ==# 'list'
    call gista#command#list#edit({
          \ 'lookup': a:gista.lookup,
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
  elseif content_type ==# 'json_entry'
    call gista#command#json#read({
          \ 'gistid': a:gista.gistid,
          \ 'entry': 1,
          \ 'cache': !v:cmdbang,
          \})
  elseif content_type ==# 'list'
    call gista#command#list#read({
          \ 'lookup': a:gista.lookup,
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
  let content = getbufline(expand('<amatch>'), 1, '$')
  echo content
endfunction
function! s:on_FileWriteCmd(gista) abort
  let content = getbufline(expand('<amatch>'), line("'["), line("']"))
  echo content
endfunction

function! gista#autocmd#call(name) abort
  let fname = 's:on_' . a:name
  if !exists('*' . fname)
    call gista#util#prompt#throw(printf(
          \ 'No autocmd function "%s" is found.', fname
          \))
  endif
  let filename = expand('<afile>')
  let gista = s:C.getbufvar('<afile>', 'gista', {})
  let gista = empty(gista)
        \ ? s:parse_filename(filename)
        \ : gista
  let session = gista#api#session({
        \ 'apiname':  get(gista, 'apiname', ''),
        \ 'username': get(gista, 'username', 0),
        \})
  try
    call session.enter()
    call call(fname, [gista])
  finally
    call session.exit()
  endtry
endfunction

let s:schemes = [
      \ ['^gista:\(.*\):\(.*\):\(.*\)$', {
      \   'apiname': 1,
      \   'gistid': 2,
      \   'filename': 3,
      \   'content_type': 'raw',
      \ }],
      \ ['^gista:\(.*\):\(.*\)\.entry\.json$', {
      \   'apiname': 1,
      \   'gistid': 2,
      \   'content_type': 'json_entry',
      \ }],
      \ ['^gista:\(.*\):\(.*\)\.json$', {
      \   'apiname': 1,
      \   'gistid': 2,
      \   'content_type': 'json',
      \ }],
      \ ['^gista-list:\(.*\):\(.*\)$', {
      \   'apiname': 1,
      \   'lookup': 2,
      \   'content_type': 'list',
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
