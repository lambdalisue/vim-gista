let s:save_cpo = &cpo
set cpo&vim

let s:V  = gista#vital()
let s:D  = s:V.import('Data.Dict')
let s:B  = s:V.import('Vim.Buffer')
let s:BM = s:V.import('Vim.BufferManager')

function! gista#util#buffer#open(name, ...) abort
  let config = get(a:000, 0, {})
  let group  = get(config, 'group', '')
  if empty(group)
    let loaded = s:B.open(a:name, get(config, 'opener', 'edit'))
    let bufnum = bufnr('%')
    return {
          \ 'loaded': loaded,
          \ 'bufnum': bufnum,
          \}
  else
    let vname = printf('_buffer_manager_%s', group)
    if !has_key(s:, vname)
      let s:{vname} = s:BM.new()
    endif
    let ret = s:{vname}.open(a:name, s:D.pick(config, [
          \ 'opener',
          \ 'range',
          \]))
    return {
          \ 'loaded': ret.loaded,
          \ 'bufnum': ret.bufnr,
          \}
  endif
endfunction
function! gista#util#buffer#read_content(content, ...) abort
  " Save the content into a tempfile and read the tempfile to achieve Vim's
  " encoding detection
  let tempfile = get(a:000, 0, tempname())
  let is_keepjumps = get(a:000, 1)
  try
    call writefile(a:content, tempfile)
    execute printf('keepalt %sread %s',
          \ is_keepjumps ? 'keepjumps ' : '',
          \ tempfile,
          \)
  finally
    call delete(tempfile)
  endtry
endfunction
function! gista#util#buffer#edit_content(content, ...) abort
  let saved_view = winsaveview()
  let saved_modifiable = &l:modifiable
  let saved_undolevels = &l:undolevels
  let &l:modifiable=1
  let &l:undolevels=-1
  silent keepjumps %delete_
  silent call gista#util#buffer#read_content(
        \ a:content, get(a:000, 0, tempname()), 1
        \)
  silent keepjumps 1delete_
  keepjump call winrestview(saved_view)
  let &l:modifiable = saved_modifiable
  let &l:undolevels = saved_undolevels
  setlocal nomodified
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
