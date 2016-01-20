let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:P = s:V.import('Vim.Prompt')

function! s:is_debug() abort
  return g:gista#debug
endfunction
function! s:is_batch() abort
  return g:gista#test
endfunction

function! gista#util#prompt#debug(...) abort
  call call(s:P.debug, a:000, s:P)
endfunction
function! gista#util#prompt#info(...) abort
  call call(s:P.info, a:000, s:P)
endfunction
function! gista#util#prompt#warn(...) abort
  call call(s:P.warn, a:000, s:P)
endfunction
function! gista#util#prompt#error(...) abort
  call call(s:P.error, a:000, s:P)
endfunction
function! gista#util#prompt#ask(...) abort
  return call(s:P.ask, a:000, s:P)
endfunction
function! gista#util#prompt#select(...) abort
  return call(s:P.select, a:000, s:P)
endfunction
function! gista#util#prompt#confirm(...) abort
  return call(s:P.confirm, a:000, s:P)
endfunction

function! gista#util#prompt#indicate(options, message) abort
  if get(a:options, 'verbose')
    redraw | echo a:message
  endif
endfunction

call s:P.set_config({
      \ 'debug': function('s:is_debug'),
      \ 'batch': function('s:is_batch'),
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
