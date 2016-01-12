let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:P = s:V.import('System.Filepath')
let s:TYPE_LIST = type([])
let s:TYPE_STRING = type('')
let s:NAME = 'vim-gista'

function! s:throw(msg) abort " {{{
  throw printf('%s: ValidationError: %s', s:NAME, a:msg)
endfunction " }}}
function! s:translate(text, table) abort " {{{
  let text = a:text
  for [key, value] in items(a:table)
    let text = substitute(
          \ text, key,
          \ type(value) == s:TYPE_STRING ? value : string(value),
          \ 'g')
    unlet value
  endfor
  return text
endfunction " }}}

function! gista#util#validate#true(value, ...) abort " {{{
  let msg = get(a:000, 0, 'A value "%value" requires to be True value')
  if !a:value
    call s:throw(s:translate(msg, {
          \ '%value': a:value,
          \}))
  endif
endfunction " }}}
function! gista#util#validate#false(value, ...) abort " {{{
  let msg = get(a:000, 0, 'A value "%value" requires to be False value')
  if a:value
    call s:throw(s:translate(msg, {
          \ '%value': a:value,
          \}))
  endif
endfunction " }}}

function! gista#util#validate#exists(value, list, ...) abort " {{{
  let msg = get(a:000, 0, 'A value "%value" reqiured to exist in %list')
  if index(a:list, a:value) == -1
    call s:throw(s:translate(msg, {
          \ '%value': a:value,
          \ '%list': a:list,
          \}))
  endif
endfunction " }}}
function! gista#util#validate#not_exists(value, list, ...) abort " {{{
  let msg = get(a:000, 0, 'A value "%value" reqiured to NOT exist in %list')
  if index(a:list, a:value) >= 0
    call s:throw(s:translate(msg, {
          \ '%value': a:value,
          \ '%list': a:list,
          \}))
  endif
endfunction " }}}

function! gista#util#validate#key_exists(value, dict, ...) abort " {{{
  let msg = get(a:000, 0, 'A key "%value" reqiured to exist in %dict')
  if !has_key(a:dict, a:value)
    call s:throw(s:translate(msg, {
          \ '%value': a:value,
          \ '%dict': a:dict,
          \}))
  endif
endfunction " }}}
function! gista#util#validate#key_not_exists(value, dict, ...) abort " {{{
  let msg = get(a:000, 0, 'A key "%value" reqiured to NOT exist in %dict')
  if has_key(a:dict, a:value)
    call s:throw(s:translate(msg, {
          \ '%value': a:value,
          \ '%dict': a:dict,
          \}))
  endif
endfunction " }}}

function! gista#util#validate#empty(value, ...) abort " {{{
  let msg = get(a:000, 0, 'Non empty value "%value" is not allowed')
  if !empty(a:value)
    call s:throw(s:translate(msg, {
          \ '%value': a:value,
          \}))
  endif
endfunction " }}}
function! gista#util#validate#not_empty(value, ...) abort " {{{
  let msg = get(a:000, 0, 'An empty value is not allowed')
  if empty(a:value)
    call s:throw(s:translate(msg, {}))
  endif
endfunction " }}}

function! gista#util#validate#pattern(value, pattern, ...) abort " {{{
  let msg = get(a:000, 0, '%value does not follow a valid pattern %pattern')
  if a:value !~# a:pattern
    call s:throw(s:translate(msg, {
          \ '%value': a:value,
          \ '%pattern': a:pattern,
          \}))
  endif
endfunction " }}}
function! gista#util#validate#not_pattern(value, pattern, ...) abort " {{{
  let msg = get(a:000, 0, '%value follow an invalid pattern %pattern')
  if a:value =~# a:pattern
    call s:throw(s:translate(msg, {
          \ '%value': a:value,
          \ '%pattern': a:pattern,
          \}))
  endif
endfunction " }}}

function! gista#util#validate#uniq(dict, keys, ...) abort " {{{
  let msg = get(a:000, 0, '%key is already be in %dict')
  let keys = s:ensure_list(a:keys)
  for key in keys
    if has_key(a:dict, key)
      call s:throw(s:translate(msg, {
            \ '%key': key,
            \ '%dict': string(a:dict),
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

function! gista#util#validate#silently(fn, ...) abort " {{{
  let args = get(a:000, 0, [])
  let default = get(a:000, 1, '')
  try
    return call(a:fn, args)
  catch /^.*: ValidationError:/
    " Make sure that a caught exception is a valid ValidationError
    if v:exception =~# printf('^%s: ValidationError:', s:NAME)
      return default
    endif
    throw v:exception
  endtry
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
