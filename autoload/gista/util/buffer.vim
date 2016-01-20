let s:save_cpo = &cpo
set cpo&vim

let s:V  = gista#vital()
let s:D  = s:V.import('Data.Dict')
let s:B  = s:V.import('Vim.Buffer')
let s:M = s:V.import('Vim.BufferManager')

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
      let s:{vname} = s:M.new()
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
function! gista#util#buffer#read_content(...) abort
  call call(s:B.read_content, a:000, s:B)
endfunction
function! gista#util#buffer#edit_content(...) abort
  call call(s:B.edit_content, a:000, s:B)
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
