let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:P = s:V.import('System.Filepath')
let s:TYPE_LIST = type([])

function! s:throw(msg) abort " {{{
  throw printf('vim-gista: ValidationError: %s', a:msg)
endfunction " }}}
function! s:ensure_list(value) abort " {{{
  return type(a:value) == s:TYPE_LIST
        \ ? a:value
        \ : [a:value]
endfunction " }}}
function! s:translate(text, table) abort " {{{
  let text = a:text
  for [key, value] in items(a:table)
    let text = substitute(text, key, value, 'g')
  endfor
  return text
endfunction " }}}

function! gista#util#validate#no_empty(values, ...) abort " {{{
  let msg = get(a:000, 0, 'An empty value is not allowed')
  let values = s:ensure_list(a:values)
  for value in values
    if empty(value)
      call s:throw(s:translate(msg, {}))
    endif
  endfor
endfunction " }}}
function! gista#util#validate#pattern(pattern, values, ...) abort " {{{
  let msg = get(a:000, 0, '%value does not follow the pattern %pattern')
  let values = s:ensure_list(a:values)
  for value in values
    if value !~# a:pattern
      call s:throw(s:translate(msg, {
            \ '%value': value,
            \ '%pattern': a:pattern,
            \}))
    endif
  endfor
endfunction " }}}
function! gista#util#validate#uniq(dict, keys, ...) abort " {{{
  let msg = get(a:000, 0, '%key is already be in %dict')
  let keys = s:ensure_list(a:keys)
  for key in keys
    if has_key(a:dict, key)
      call s:throw(s:translate(msg, {
            \ '%key': key,
            \ '%dict': a:dict,
            \}))
    endif
  endfor
endfunction " }}}
function! gista#util#validate#no_uniq(dict, keys, ...) abort " {{{
  let msg = get(a:000, 0, '%key is not found in %dict')
  let keys = s:ensure_list(a:keys)
  for key in keys
    if !has_key(a:dict, key)
      call s:throw(s:translate(msg, {
            \ '%key': key,
            \ '%dict': a:dict,
            \}))
    endif
  endfor
endfunction " }}}

function! gista#util#validate#silently(fname, ...) abort " {{{
  try
    return call(a:fname, a:000)
  catch /^vim-gista: ValidationError/
    return ''
  endtry
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
